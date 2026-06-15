# frozen_string_literal: true

class CarService
  SEARCH_INDEX_MUTEX = Mutex.new

  attr_reader :user

  def self.ensure_text_search_index!
    return if @text_search_index_checked

    SEARCH_INDEX_MUTEX.synchronize do
      return if @text_search_index_checked

      refresh_text_search_index! unless text_search_index_current?
      @text_search_index_checked = true
    end
  end

  def self.text_search_index_current?
    index = text_search_index
    index.present? && !index.fetch('weights', {}).key?('manufacturer')
  end

  def self.refresh_text_search_index!
    Car.collection.indexes.drop_one('CarTextIndex') if text_search_index
    Car.create_indexes
  end

  def self.text_search_index
    Car.collection.indexes.to_a.find { |index| index['name'] == 'CarTextIndex' }
  rescue Mongo::Error::OperationFailure => e
    return nil if e.code == 26

    raise
  end

  def initialize(user)
    @user = user
  end

  def create(params)
    prepared_params = normalize_params(params)
    enqueue_processing = should_process_photo?(prepared_params)
    car = user.cars.build(prepared_params)
    add_create_errors(car, prepared_params)
    return car if car.errors.any?

    mark_photo_as_pending(car, prepared_params) if enqueue_processing
    enqueue_processing = false unless car.save
    enqueue_photo_processing(car, prepared_params) if enqueue_processing
    car
  end

  def update(car_id, params)
    car = user.cars.find(car_id)
    prepared_params = normalize_params(params)
    enqueue_processing = should_process_photo?(prepared_params)
    variant_toggle = photo_variant_toggle_requested?(car, prepared_params, enqueue_processing)
    car.attributes = prepared_params
    reset_photo_versions(car) if replacing_photo?(prepared_params)
    clear_photo_processing(car) if remove_photo?(prepared_params)
    enqueue_processing = apply_photo_variant_toggle(car, prepared_params) == :enqueue if variant_toggle
    mark_photo_as_pending(car, prepared_params) if enqueue_processing
    enqueue_processing = false unless car.save
    enqueue_photo_processing(car, prepared_params) if enqueue_processing
    car
  end

  def destroy(car_id)
    car = user.cars.find_by(id: car_id)
    return nil unless car

    car.destroy
    car
  end

  def all(params = {})
    page = (params[:page] || 1).to_i
    per_page = params[:per_page] || 20
    query = params[:q]

    scope = query.present? ? search(query) : user.cars.all

    scope.desc(:created_at).page(page).per(per_page)
  end

  def search(query)
    words = query.to_s.strip
    return user.cars if words.empty?

    self.class.ensure_text_search_index!
    user.cars.where('$text' => { '$search' => words })
  end

  private

  def car_image_minimum_side
    ImageUpscalerService.default_minimum_side
  end

  def normalize_params(params)
    params.to_h.deep_symbolize_keys
  end

  def should_process_photo?(params)
    return false if remove_photo?(params)

    params[:photo].present? || crop_requested?(params)
  end

  def photo_variant_toggle_requested?(car, params, enqueue_processing)
    params.key?(:skip_upscaler) && car.photo.present? && !enqueue_processing && !remove_photo?(params)
  end

  def apply_photo_variant_toggle(car, params)
    skip_upscaler = ActiveModel::Type::Boolean.new.cast(params[:skip_upscaler])

    if skip_upscaler
      use_original_photo(car)
      return :skip
    end

    unless ai_upscale_relevant?(car)
      use_original_photo(car) if car.original_photo_available?
      return :skip
    end

    unless user.ai_upscaling_enabled?
      use_original_photo(car) if car.original_photo_available?
      return :skip
    end

    if car.enhanced_photo_available?
      apply_enhanced_photo(car)
      return :skip
    end
    return :skip unless user.ai_upscaling_enabled? && ImageUpscalerService.service_configured?

    use_original_photo(car) if car.original_photo_available?
    params[:bulk_ai_upscale] = false
    params[:force_ai_upscale] = true
    :enqueue
  end

  def use_original_photo(car)
    return unless car.original_photo_available?

    File.open(car.original_photo.path) do |file|
      car.photo = file
      car.photo.store!
      car.write_attribute(:photo_filename, car.photo.identifier)
    end
    car.photo_variant = 'original'
    car.photo_upscale_strategy = nil
    car.skip_upscaler = true
  end

  def apply_enhanced_photo(car)
    File.open(car.enhanced_photo.path) do |file|
      car.photo = file
      car.photo.store!
      car.write_attribute(:photo_filename, car.photo.identifier)
    end
    car.photo_variant = 'ai'
    car.photo_upscale_strategy = 'ai'
    car.skip_upscaler = false
    nil
  end

  def replacing_photo?(params)
    params[:photo].present? || params[:remote_photo_url].present?
  end

  def reset_photo_versions(car)
    car.remove_original_photo = true if car.respond_to?(:remove_original_photo=)
    car.remove_enhanced_photo = true if car.respond_to?(:remove_enhanced_photo=)
    car.write_attribute(:original_photo_filename, nil)
    car.write_attribute(:enhanced_photo_filename, nil)
    car.photo_variant = nil
    car.photo_upscale_strategy = nil
    clear_photo_crop(car)
  end

  def ai_upscale_relevant?(car)
    source = car.original_photo? ? car.original_photo : car.photo
    return false unless source&.path

    ImageUpscalerService.upscale_needed?(source.path, minimum_side: car_image_minimum_side)
  end

  def crop_requested?(params)
    params[:crop_x].present? && params[:crop_y].present? && params[:crop_w].present? && params[:crop_h].present?
  end

  def remove_photo?(params)
    ActiveModel::Type::Boolean.new.cast(params[:remove_photo])
  end

  def missing_photo_on_create?(params)
    params.values_at(:photo, :remote_photo_url, :photo_cache).all?(&:blank?)
  end

  def add_create_errors(car, params)
    car.validate
    car.errors.add(:photo, :blank) if missing_photo_on_create?(params)
  end

  def mark_photo_as_pending(car, params)
    car.photo_processing_status = 'pending'
    car.photo_processing_error = nil
    store_processing_crop(car, params)
  end

  def clear_photo_processing(car)
    car.photo_processing_status = nil
    car.photo_processing_error = nil
    clear_processing_crop(car)
    clear_photo_crop(car)
  end

  def enqueue_photo_processing(car, params)
    CarImageProcessingJob.perform_later(user.id.to_s, car.id.to_s, photo_processing_params(params))
  end

  def crop_params(params)
    params.slice(:crop_x, :crop_y, :crop_w, :crop_h, :photo_upscale_strategy, :force_ai_upscale,
                 :bulk_ai_upscale).compact
  end

  def photo_processing_params(params)
    crop_params(params).tap do |processing_params|
      processing_params[:force_ai_upscale] = true if ai_upscale_selected?(params)
    end
  end

  def ai_upscale_selected?(params)
    return false unless params.key?(:skip_upscaler)
    return false unless user.ai_upscaling_enabled? && ImageUpscalerService.service_configured?

    !ActiveModel::Type::Boolean.new.cast(params[:skip_upscaler])
  end

  def store_processing_crop(car, params)
    return clear_processing_crop(car) unless crop_requested?(params)

    car.photo_processing_crop_x = params[:crop_x]
    car.photo_processing_crop_y = params[:crop_y]
    car.photo_processing_crop_w = params[:crop_w]
    car.photo_processing_crop_h = params[:crop_h]
    car.photo_crop_x = params[:crop_x]
    car.photo_crop_y = params[:crop_y]
    car.photo_crop_w = params[:crop_w]
    car.photo_crop_h = params[:crop_h]
  end

  def clear_processing_crop(car)
    car.photo_processing_crop_x = nil
    car.photo_processing_crop_y = nil
    car.photo_processing_crop_w = nil
    car.photo_processing_crop_h = nil
  end

  def clear_photo_crop(car)
    car.photo_crop_x = nil
    car.photo_crop_y = nil
    car.photo_crop_w = nil
    car.photo_crop_h = nil
  end
end

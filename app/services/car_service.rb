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
    car.attributes = prepared_params
    clear_photo_processing(car) if remove_photo?(prepared_params)
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
  end

  def enqueue_photo_processing(car, params)
    CarImageProcessingJob.perform_later(user.id.to_s, car.id.to_s, crop_params(params))
  end

  def crop_params(params)
    params.slice(:crop_x, :crop_y, :crop_w, :crop_h, :photo_upscale_strategy).compact
  end

  def store_processing_crop(car, params)
    return clear_processing_crop(car) unless crop_requested?(params)

    car.photo_processing_crop_x = params[:crop_x]
    car.photo_processing_crop_y = params[:crop_y]
    car.photo_processing_crop_w = params[:crop_w]
    car.photo_processing_crop_h = params[:crop_h]
  end

  def clear_processing_crop(car)
    car.photo_processing_crop_x = nil
    car.photo_processing_crop_y = nil
    car.photo_processing_crop_w = nil
    car.photo_processing_crop_h = nil
  end
end

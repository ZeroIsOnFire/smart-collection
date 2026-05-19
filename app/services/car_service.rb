# frozen_string_literal: true

class CarService
  CAR_IMAGE_MINIMUM_SIDE = ImageUpscalerService::DEFAULT_MINIMUM_SIDE
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def create(params)
    prepared_params, upscaled_file = prepare_photo_for_save(params, minimum_side: CAR_IMAGE_MINIMUM_SIDE)
    car = user.cars.build(prepared_params)
    process_car_image(car, prepared_params)
    car.save
    car
  rescue ImageUpscalerService::UpscaleError => e
    car = user.cars.build(params.to_h.deep_symbolize_keys.except(:photo))
    car.errors.add(:photo, e.message)
    car
  ensure
    cleanup_tempfile(upscaled_file)
  end

  def update(car_id, params)
    car = user.cars.find(car_id)
    prepared_params, upscaled_file = prepare_photo_for_save(params, minimum_side: CAR_IMAGE_MINIMUM_SIDE)
    car.attributes = prepared_params
    process_car_image(car, prepared_params)
    car.save
    car
  rescue ImageUpscalerService::UpscaleError => e
    car.errors.add(:photo, e.message)
    car
  ensure
    cleanup_tempfile(upscaled_file)
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

    user.cars.where('$text' => { '$search' => words })
  end

  private

  def prepare_photo_for_save(params, minimum_side:)
    normalized_params = params.to_h.deep_symbolize_keys
    photo = normalized_params[:photo]

    return [normalized_params, nil] if photo.blank?

    upscaled_file = ImageUpscalerService.upscale_if_needed(photo, minimum_side: minimum_side)
    normalized_params[:photo] = upscaled_file if upscaled_file

    [normalized_params, upscaled_file]
  end

  def process_car_image(car, params)
    apply_crop(car, params)

    car.crop_x = car.crop_y = car.crop_w = car.crop_h = nil

    return unless car.photo.present? && car.color.blank?

    detected_color = YoloDetectionService.classify_color(car.photo.path)
    car.color = detected_color if detected_color
  end

  def apply_crop(car, params)
    crop_x = params[:crop_x]
    crop_y = params[:crop_y]
    crop_w = params[:crop_w]
    crop_h = params[:crop_h]

    return unless crop_x.present? && car.photo.present?

    vertices = [
      { 'x' => crop_x.to_f, 'y' => crop_y.to_f },
      { 'x' => crop_x.to_f + crop_w.to_f, 'y' => crop_y.to_f },
      { 'x' => crop_x.to_f + crop_w.to_f, 'y' => crop_y.to_f + crop_h.to_f },
      { 'x' => crop_x.to_f, 'y' => crop_y.to_f + crop_h.to_f }
    ]

    cropped_file = ImageCropperService.crop(car.photo.path, vertices, padding: 0, minimum_side: CAR_IMAGE_MINIMUM_SIDE)
    car.photo = cropped_file if cropped_file
  end

  def cleanup_tempfile(tempfile)
    return unless tempfile.respond_to?(:close)

    tempfile.close
    tempfile.unlink
  rescue StandardError
    nil
  end
end

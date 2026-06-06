# frozen_string_literal: true

class CarImageProcessingJob < ApplicationJob
  queue_as :default

  def perform(user_id, car_id, crop_params = {})
    user = User.find(user_id)
    car = user.cars.find(car_id)
    return clear_processing_state(car) if car.photo.blank?

    update_processing_state(car, status: 'processing')

    processed_file = process_photo(car, crop_params.to_h.deep_symbolize_keys)
    classify_color(car)

    car.photo_processing_status = 'completed'
    car.photo_processing_error = nil
    clear_processing_crop(car)
    car.save!
    broadcast_car(car)
  rescue Mongoid::Errors::DocumentNotFound
    nil
  rescue StandardError => e
    Rails.logger.error "CarImageProcessingJob failed for car #{car_id}: #{e.message}"
    mark_as_failed(user_id, car_id, e.message)
  ensure
    cleanup_tempfile(processed_file)
  end

  private

  def process_photo(car, crop_params)
    crop_requested?(crop_params) ? apply_crop(car, crop_params) : apply_upscale(car)
  end

  def apply_upscale(car)
    upscaled_file = ImageUpscalerService.upscale_if_needed(
      car.photo.path,
      minimum_side: ImageUpscalerService.default_minimum_side,
      use_ai: car.user.ai_upscaling_enabled?,
      local_fallback: false
    )

    store_processed_photo(car, upscaled_file) if upscaled_file
    upscaled_file
  end

  def apply_crop(car, crop_params)
    cropped_file = ImageCropperService.crop(
      car.photo.path,
      crop_vertices(crop_params),
      padding: 0,
      minimum_side: ImageUpscalerService.default_minimum_side,
      upscale: { use_ai: car.user.ai_upscaling_enabled?, local_fallback: false }
    )

    store_processed_photo(car, cropped_file) if cropped_file
    cropped_file
  end

  def store_processed_photo(car, file)
    car.photo = file
    car.photo.store!
    car.write_attribute(:photo_filename, car.photo.identifier)
  end

  def classify_color(car)
    return unless car.photo.present? && !car.color?

    detected_color = YoloDetectionService.classify_color(car.photo.path)
    car.color = detected_color if detected_color
  end

  def crop_requested?(crop_params)
    crop_params[:crop_x].present? && crop_params[:crop_y].present? &&
      crop_params[:crop_w].present? && crop_params[:crop_h].present?
  end

  def crop_vertices(crop_params)
    crop_x = crop_params[:crop_x].to_f
    crop_y = crop_params[:crop_y].to_f
    crop_w = crop_params[:crop_w].to_f
    crop_h = crop_params[:crop_h].to_f

    [
      { 'x' => crop_x, 'y' => crop_y },
      { 'x' => rounded(crop_x + crop_w), 'y' => crop_y },
      { 'x' => rounded(crop_x + crop_w), 'y' => rounded(crop_y + crop_h) },
      { 'x' => crop_x, 'y' => rounded(crop_y + crop_h) }
    ]
  end

  def rounded(value)
    value.round(10)
  end

  def clear_processing_state(car)
    car.update!(
      photo_processing_status: nil,
      photo_processing_error: nil,
      photo_processing_crop_x: nil,
      photo_processing_crop_y: nil,
      photo_processing_crop_w: nil,
      photo_processing_crop_h: nil
    )
    broadcast_car(car)
  end

  def mark_as_failed(user_id, car_id, message)
    user = User.find(user_id)
    car = user.cars.find(car_id)
    car.update!(
      photo_processing_status: 'error',
      photo_processing_error: message,
      photo_processing_crop_x: nil,
      photo_processing_crop_y: nil,
      photo_processing_crop_w: nil,
      photo_processing_crop_h: nil
    )
    broadcast_car(car)
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  def clear_processing_crop(car)
    car.photo_processing_crop_x = nil
    car.photo_processing_crop_y = nil
    car.photo_processing_crop_w = nil
    car.photo_processing_crop_h = nil
  end

  def update_processing_state(car, status:)
    car.update!(photo_processing_status: status, photo_processing_error: nil)
    broadcast_car(car)
  end

  def broadcast_car(car)
    Turbo::StreamsChannel.broadcast_replace_to(
      "cars_#{car.user_id}",
      target: "car_#{car.id}",
      partial: 'cars/car',
      locals: { car: car }
    )
  end

  def cleanup_tempfile(tempfile)
    return unless tempfile.respond_to?(:close)

    tempfile.close
    tempfile.unlink
  rescue StandardError
    nil
  end
end

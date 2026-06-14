# frozen_string_literal: true

class DetectedItemImageProcessingJob < ApplicationJob
  queue_as :default

  def perform(user_id, detected_item_id, attributes = {})
    detected_item = find_detected_item(user_id, detected_item_id)
    return unless detected_item

    detected_item.update!(image_processing_status: 'processing', image_processing_error: nil)

    processed_file = crop_item_photo(detected_item)
    classification = classify(processed_file)

    track_upscaled_photo(processed_file)
    apply_processing_result(detected_item, processed_file, classification, attributes.to_h.deep_symbolize_keys)
    broadcast_detected_item(detected_item)
  rescue StandardError => e
    Rails.logger.error "DetectedItemImageProcessingJob failed for item #{detected_item_id}: #{e.message}"
    mark_as_failed(user_id, detected_item_id, e.message)
  ensure
    cleanup_tempfile(processed_file)
  end

  private

  def find_detected_item(user_id, detected_item_id)
    detected_item = DetectedItem.find(detected_item_id)
    detected_item if detected_item.autodetection.user_id.to_s == user_id.to_s
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  def crop_item_photo(detected_item)
    ImageCropperService.crop(
      detected_item.autodetection.photo.path,
      detected_item.position_data['vertices'],
      padding: 0,
      minimum_side: ImageCropperService.default_minimum_side,
      upscale: upscale_options(detected_item)
    )
  end

  def upscale_options(detected_item)
    enabled = detected_item.autodetection.user.ai_upscaling_enabled? && !detected_item.skip_upscaler?

    { use_ai: enabled, local_fallback: enabled }
  end

  def classify(processed_file)
    return {} unless processed_file

    YoloDetectionService.classify(processed_file.path)
  end

  def track_upscaled_photo(file)
    return unless file.respond_to?(:upscale_strategy)

    UsageMetric.record!("photos_upscaled_#{file.upscale_strategy}")
  end

  def apply_processing_result(detected_item, processed_file, classification, attributes)
    detected_item.cropped_photo = processed_file if processed_file
    detected_item.cropped_photo_upscale_strategy = detected_item_upscale_strategy(detected_item, processed_file)
    detected_item.label = attributes[:name].presence || classification[:label].presence || detected_item.label
    detected_item.color = resolved_color(detected_item, classification, attributes)
    detected_item.brand = attributes[:brand] if attributes.key?(:brand)
    detected_item.year = attributes[:year] if attributes.key?(:year)
    detected_item.size = attributes[:size] if attributes.key?(:size)
    detected_item.skip_upscaler = attributes[:skip_upscaler] if attributes.key?(:skip_upscaler)
    detected_item.image_processing_status = 'completed'
    detected_item.image_processing_error = nil
    detected_item.save!
  end

  def resolved_color(detected_item, classification, attributes)
    submitted_color = attributes[:color]
    detected_color = classification[:color]

    return detected_color if submitted_color.blank?
    return detected_color if submitted_color == detected_item.color && detected_color.present?

    submitted_color
  end

  def upscale_strategy(file)
    return unless file.respond_to?(:upscale_strategy)

    file.upscale_strategy.to_s
  end

  def detected_item_upscale_strategy(detected_item, file)
    upscale_strategy(file).presence || detected_item.autodetection.photo_upscale_strategy
  end

  def broadcast_detected_item(detected_item)
    Turbo::StreamsChannel.broadcast_replace_to(
      "autodetection_#{detected_item.autodetection_id}_items",
      target: "detected_item_#{detected_item.id}",
      partial: 'detected_items/detected_item',
      locals: { detected_item: detected_item }
    )
  end

  def mark_as_failed(user_id, detected_item_id, message)
    detected_item = find_detected_item(user_id, detected_item_id)
    return unless detected_item

    detected_item.update!(image_processing_status: 'error', image_processing_error: message)
    broadcast_detected_item(detected_item)
  end

  def cleanup_tempfile(tempfile)
    return unless tempfile.respond_to?(:close)

    tempfile.close
    tempfile.unlink
  rescue StandardError
    nil
  end
end

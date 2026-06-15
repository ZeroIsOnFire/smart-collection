# frozen_string_literal: true

class AutodetectJob < ApplicationJob
  queue_as :default

  def perform(autodetection_id)
    autodetection = Autodetection.find(autodetection_id)
    return unless autodetection

    autodetection.update!(status: 'processing')

    begin
      detected_items_data = []

      if YoloDetectionService.service_configured?
        Rails.logger.info "AutodetectJob: Attempting YOLO detection for autodetection #{autodetection_id}"
        detected_items_data = YoloDetectionService.analyze(autodetection.photo.path)
      end

      Rails.logger.info "AutodetectJob: No items found for autodetection #{autodetection_id}" if detected_items_data.empty?

      detected_items_data.each do |data|
        cropped_file = nil
        begin
          cropped_file = ImageCropperService.crop(
            autodetection.photo.path,
            data[:vertices],
            minimum_side: ImageCropperService.default_minimum_side,
            upscale: { use_ai: false, local_fallback: false }
          )

          next unless cropped_file

          autodetection.detected_items.create!(
            label: I18n.t('autodetections.detected_item.new_item'),
            color: data[:color],
            skip_upscaler: autodetection.skip_upscaler?,
            position_data: {
              vertices: data[:vertices],
              score: data[:score]
            },
            cropped_photo: cropped_file
          )
          UsageMetric.record!('yolo_detected_items')
        ensure
          cleanup_tempfile(cropped_file)
        end
      end

      autodetection.update!(status: 'to_verify', error_message: nil)
    rescue StandardError => e
      Rails.logger.error "AutodetectJob Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      autodetection.update!(status: 'error', error_message: e.message)
    end
  end

  private

  def cleanup_tempfile(tempfile)
    return unless tempfile.respond_to?(:close)

    tempfile.close
    tempfile.unlink
  rescue StandardError
    nil
  end
end

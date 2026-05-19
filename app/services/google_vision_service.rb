# frozen_string_literal: true

require 'google/cloud/vision'
require 'google/cloud/vision/v1'
require 'tempfile'

class GoogleVisionService
  TARGET_LABELS = ['Toy', 'Car', 'Vehicle', 'Model car'].freeze
  MAX_RESULTS = 100

  def self.analyze(photo_path)
    return [] unless credentials_configured?

    upscaled_file = ImageUpscalerService.upscale_if_needed(photo_path, minimum_side: ImageUpscalerService::DEFAULT_MINIMUM_SIDE)
    working_path = upscaled_file&.path || photo_path
    vision_enhanced_file = ImageUpscalerService.upscale_if_needed(working_path, minimum_side: 1080)
    analysis_path = vision_enhanced_file&.path || working_path

    begin
      image_annotator = Google::Cloud::Vision.image_annotator do |config|
        config.credentials = ENV.fetch('GOOGLE_CLOUD_CREDENTIALS_PATH', nil)
      end
      response = image_annotator.object_localization_detection(image: analysis_path, max_results: MAX_RESULTS)
    rescue StandardError => e
      if simulation_mode? || e.message.include?('billing')
        Rails.logger.warn "GoogleVisionService: Simulation mode enabled (due to error: #{e.message})"
        return simulate_detection
      end
      raise e
    ensure
      cleanup_tempfile(vision_enhanced_file)
      cleanup_tempfile(upscaled_file)
    end

    return simulate_detection if simulation_mode?

    detected_items = []

    response.responses.each do |res|
      res.localized_object_annotations.each do |obj|
        next unless TARGET_LABELS.any? { |label| obj.name.to_s.downcase.include?(label.downcase) }

        detected_items << {
          label: obj.name,
          score: obj.score,
          vertices: obj.bounding_poly.normalized_vertices.map { |v| { x: v.x, y: v.y } }
        }
      end
    end

    detected_items
  end

  def self.simulation_mode?
    enabled = ENV['VISION_SIMULATION_MODE'] == 'true'
    Rails.logger.error '[SEGURANCA] VISION_SIMULATION_MODE is enabled in production!' if enabled && Rails.env.production?
    enabled
  end

  def self.simulate_detection
    [
      {
        label: 'Toy Car (Simulado)',
        score: 0.99,
        vertices: [{ x: 0.1, y: 0.1 }, { x: 0.4, y: 0.1 }, { x: 0.4, y: 0.4 }, { x: 0.1, y: 0.4 }]
      },
      {
        label: 'Hot Wheels (Simulado)',
        score: 0.95,
        vertices: [{ x: 0.6, y: 0.1 }, { x: 0.9, y: 0.1 }, { x: 0.9, y: 0.4 }, { x: 0.6, y: 0.4 }]
      },
      {
        label: 'Matchbox (Simulado)',
        score: 0.88,
        vertices: [{ x: 0.3, y: 0.6 }, { x: 0.7, y: 0.6 }, { x: 0.7, y: 0.9 }, { x: 0.3, y: 0.9 }]
      }
    ]
  end

  def self.credentials_configured?
    credentials_path = ENV.fetch('GOOGLE_CLOUD_CREDENTIALS_PATH', nil)

    credentials_path.present? && File.exist?(credentials_path)
  end

  def self.cleanup_tempfile(tempfile)
    return unless tempfile.respond_to?(:close)

    tempfile.close
    tempfile.unlink
  rescue StandardError
    nil
  end
  private_class_method :cleanup_tempfile
end

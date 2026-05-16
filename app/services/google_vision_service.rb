# frozen_string_literal: true

require 'google/cloud/vision'
require 'google/cloud/vision/v1'

class GoogleVisionService
  TARGET_LABELS = ['Toy', 'Car', 'Vehicle', 'Model car'].freeze
  MAX_RESULTS = 100

  def self.analyze(photo_path)
    return [] unless credentials_configured?

    # Enhance image if it's too small before sending to Google
    enhance_image!(photo_path)

    begin
      image_annotator = Google::Cloud::Vision.image_annotator do |config|
        config.credentials = ENV.fetch('GOOGLE_CLOUD_CREDENTIALS_PATH', nil)
      end
      response = image_annotator.object_localization_detection(image: photo_path, max_results: MAX_RESULTS)
    rescue StandardError => e
      if simulation_mode? || e.message.include?('billing')
        Rails.logger.warn "GoogleVisionService: Simulation mode enabled (due to error: #{e.message})"
        return simulate_detection
      end
      raise e
    end

    return simulate_detection if simulation_mode?

    detected_items = []

    response.responses.each do |res|
      res.localized_object_annotations.each do |obj|
        # Verifica se a label está na nossa lista de alvos ou se tem um score decente
        next unless TARGET_LABELS.any? { |label| obj.name.to_s.downcase.include?(label.downcase) }

        detected_items << {
          label: obj.name,
          score: obj.score,
          # O Vision retorna vértices normalizados (0.0 a 1.0)
          vertices: obj.bounding_poly.normalized_vertices.map { |v| { x: v.x, y: v.y } }
        }
      end
    end

    detected_items
  end

  def self.simulation_mode?
    enabled = ENV['VISION_SIMULATION_MODE'] == 'true'
    Rails.logger.error '[SEGURANÇA] VISION_SIMULATION_MODE está habilitado em produção! Desabilite imediatamente.' if enabled && Rails.env.production?
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

  def self.enhance_image!(photo_path)
    image = MiniMagick::Image.open(photo_path)
    # Check if any side is less than 1080px
    if image.width < 1080 || image.height < 1080
      Rails.logger.info "Enhancing small image (#{image.width}x#{image.height}) before Vision API analysis"
      image.combine_options do |c|
        # Resize so the smaller side is at least 1080px (maintaining aspect ratio)
        c.resize '1080x1080^'
        # Sharpening
        c.sharpen '0x1'
        # Contrast improvement (auto-level is generally very effective)
        c.auto_level
        # Quality improvement/setting
        c.quality '100'
        # Improve contrast
        c.contrast
        # Ensure correct orientation based on EXIF
        c.auto_orient
      end
      image.write(photo_path)
    end
  rescue StandardError => e
    Rails.logger.error "Image enhancement failed: #{e.message}"
  end

  private_class_method :enhance_image!
end

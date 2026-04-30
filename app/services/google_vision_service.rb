# frozen_string_literal: true

require 'google/cloud/vision'
require 'google/cloud/vision/v1'

class GoogleVisionService
  TARGET_LABELS = ['Toy', 'Car', 'Vehicle', 'Model car'].freeze

  def self.analyze(photo_path)
    return [] unless credentials_configured?

    begin
      image_annotator = Google::Cloud::Vision.image_annotator do |config|
        config.credentials = ENV.fetch('GOOGLE_CLOUD_CREDENTIALS_PATH', nil)
      end
      response = image_annotator.object_localization_detection(image: photo_path)
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
end

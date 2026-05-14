# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class YoloDetectionService
  def self.analyze(photo_path)
    return [] unless service_configured?

    url = URI.parse("#{ENV.fetch('YOLO_SERVICE_URL')}/detect")
    api_key = ENV.fetch('YOLO_API_KEY')

    begin
      request = Net::HTTP::Post.new(url)
      request['X-API-Key'] = api_key
      
      # Use multipart form data for file upload
      form_data = [['file', File.open(photo_path)]]
      request.set_form(form_data, 'multipart/form-data')

      response = Net::HTTP.start(url.host, url.port) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        process_detections(data['detections'])
      else
        Rails.logger.error "YoloDetectionService Error: #{response.code} - #{response.body}"
        []
      end
    rescue StandardError => e
      Rails.logger.error "YoloDetectionService Exception: #{e.message}"
      []
    end
  end

  def self.service_configured?
    ENV['YOLO_SERVICE_URL'].present? && ENV['YOLO_API_KEY'].present?
  end

  def self.process_detections(detections)
    detections.map do |det|
      {
        label: det['label'],
        score: det['score'],
        vertices: det['vertices'].map { |v| { x: v['x'], y: v['y'] } }
      }
    end
  end

  private_class_method :process_detections
end

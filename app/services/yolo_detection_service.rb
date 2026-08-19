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
      Observability.inject_trace_context!(request)

      # Use multipart form data for file upload
      form_data = [['file', File.open(photo_path)]]
      request.set_form(form_data, 'multipart/form-data')

      response = Observability.in_span('YOLO detect') do
        Net::HTTP.start(url.host, url.port) { |http| http.request(request) }
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

  def self.classify_color(photo_path)
    return nil unless service_configured?

    url = URI.parse("#{ENV.fetch('YOLO_SERVICE_URL')}/classify_color")
    api_key = ENV.fetch('YOLO_API_KEY')

    begin
      request = Net::HTTP::Post.new(url)
      request['X-API-Key'] = api_key
      Observability.inject_trace_context!(request)

      form_data = [['file', File.open(photo_path)]]
      request.set_form(form_data, 'multipart/form-data')

      response = Observability.in_span('YOLO classify color') do
        Net::HTTP.start(url.host, url.port) { |http| http.request(request) }
      end

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        normalize_color(data['color'])
      else
        Rails.logger.error "YoloDetectionService classify_color Error: #{response.code} - #{response.body}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "YoloDetectionService classify_color Exception: #{e.message}"
      nil
    end
  end

  def self.classify(photo_path)
    return {} unless service_configured?

    url = URI.parse("#{ENV.fetch('YOLO_SERVICE_URL')}/classify")
    api_key = ENV.fetch('YOLO_API_KEY')

    begin
      request = Net::HTTP::Post.new(url)
      request['X-API-Key'] = api_key
      Observability.inject_trace_context!(request)

      form_data = [['file', File.open(photo_path)]]
      request.set_form(form_data, 'multipart/form-data')

      response = Observability.in_span('YOLO classify') do
        Net::HTTP.start(url.host, url.port) { |http| http.request(request) }
      end

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body).symbolize_keys
        result[:color] = normalize_color(result[:color]) if result.key?(:color)
        result
      else
        Rails.logger.error "YoloDetectionService classify Error: #{response.code} - #{response.body}"
        {}
      end
    rescue StandardError => e
      Rails.logger.error "YoloDetectionService classify Exception: #{e.message}"
      {}
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
        color: normalize_color(det['color']),
        vertices: det['vertices'].map { |v| { x: v['x'], y: v['y'] } }
      }
    end
  end

  def self.normalize_color(color)
    Car::LEGACY_COLOR_KEYS.fetch(color, color)
  end

  private_class_method :process_detections, :normalize_color
end

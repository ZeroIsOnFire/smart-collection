# frozen_string_literal: true

require 'mini_magick'
require 'net/http'
require 'tempfile'
require 'uri'

class ImageUpscalerService
  DEFAULT_MINIMUM_SIDE = 360
  DEFAULT_MINIMUM_SIDE_ENV = 'IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE'
  class UpscaleError < StandardError; end

  def self.default_minimum_side
    minimum_side_from_env(DEFAULT_MINIMUM_SIDE_ENV, DEFAULT_MINIMUM_SIDE)
  end

  def self.minimum_side_from_env(env_key, fallback)
    value = ENV.fetch(env_key, nil).to_s.to_i

    value.positive? ? value : fallback
  end

  def self.upscale_if_needed(photo_path, minimum_side: default_minimum_side, use_ai: true, local_fallback: true)
    source_path = resolved_photo_path(photo_path)
    return nil if source_path.blank?

    image = MiniMagick::Image.open(source_path)
    return nil if [image.width, image.height].min >= minimum_side

    if use_ai && service_configured?
      upscale_via_service(source_path, minimum_side)
    elsif local_fallback
      upscale_locally(source_path, minimum_side)
    end
  rescue UpscaleError
    raise
  rescue StandardError => e
    Rails.logger.error "ImageUpscalerService: #{e.message}"
    raise UpscaleError, e.message
  end

  def self.service_configured?
    ENV['IMAGE_UPSCALE_SERVICE_URL'].present?
  end

  def self.resolved_photo_path(photo_path)
    return photo_path.path if photo_path.respond_to?(:path)

    photo_path.to_s
  end
  private_class_method :resolved_photo_path

  def self.upscale_via_service(source_path, minimum_side)
    service_url = ENV.fetch('IMAGE_UPSCALE_SERVICE_URL')
    url = URI.parse("#{service_url}/upscale?minimum_side=#{minimum_side}")
    Rails.logger.info "ImageUpscalerService: sending upscale request to #{url} for #{source_path} (min side: #{minimum_side})"
    api_key = ENV['IMAGE_UPSCALE_API_KEY'].presence

    request = Net::HTTP::Post.new(url)
    request['X-API-Key'] = api_key if api_key.present?
    response = File.open(source_path) do |file|
      request.set_form([
                         ['file', file]
                       ], 'multipart/form-data')

      Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') do |http|
        http.request(request)
      end
    end

    raise UpscaleError, "remote service responded with #{response.code}" unless response.is_a?(Net::HTTPSuccess) && response.body.present?

    Rails.logger.info "ImageUpscalerService: upscale request succeeded with response body size #{response.body.bytesize} bytes"

    tempfile = build_tempfile_from_bytes(source_path, response.body, strategy: :ai)
    return tempfile if meets_minimum_side?(tempfile.path, minimum_side)

    cleanup_tempfile(tempfile)
    raise UpscaleError, 'remote service returned an image below the requested size'
  rescue UpscaleError
    raise
  rescue StandardError => e
    Rails.logger.error "ImageUpscalerService remote upscale failed: #{e.message}"
    raise UpscaleError, e.message
  end
  private_class_method :upscale_via_service

  def self.upscale_locally(source_path, minimum_side)
    image = MiniMagick::Image.open(source_path)
    image.combine_options do |c|
      c.auto_orient
      c.quality '100'
    end
    resize_image_to_minimum_side!(image, minimum_side)

    tempfile = Tempfile.new(["upscale_#{File.basename(source_path, File.extname(source_path))}_", '.jpg'], Rails.root.join('tmp'))
    tempfile.binmode
    image.write(tempfile.path)
    tempfile.rewind
    attach_metadata(tempfile, source_path, strategy: :local)
  rescue StandardError => e
    Rails.logger.error "ImageUpscalerService local upscale failed: #{e.message}"
    raise UpscaleError, e.message
  end
  private_class_method :upscale_locally

  def self.resize_image_to_minimum_side!(image, minimum_side)
    return image if [image.width, image.height].min >= minimum_side

    if image.width <= image.height
      image.resize "#{minimum_side}x"
    else
      image.resize "x#{minimum_side}"
    end

    image
  end

  def self.build_tempfile_from_bytes(source_path, bytes, strategy:)
    tempfile = Tempfile.new(["upscale_#{File.basename(source_path, File.extname(source_path))}_", '.jpg'], Rails.root.join('tmp'))
    tempfile.binmode
    tempfile.write(bytes)
    tempfile.rewind
    attach_metadata(tempfile, source_path, strategy: strategy)
  end
  private_class_method :build_tempfile_from_bytes

  def self.attach_metadata(tempfile, source_path, strategy:)
    original_name = "#{File.basename(source_path, File.extname(source_path))}.jpg"

    tempfile.define_singleton_method(:original_filename) { original_name }
    tempfile.define_singleton_method(:content_type) { 'image/jpeg' }
    tempfile.define_singleton_method(:upscale_strategy) { strategy }
    tempfile
  end
  private_class_method :attach_metadata

  def self.meets_minimum_side?(path, minimum_side)
    image = MiniMagick::Image.open(path)
    [image.width, image.height].min >= minimum_side
  rescue StandardError
    false
  end
  private_class_method :meets_minimum_side?

  def self.cleanup_tempfile(tempfile)
    return unless tempfile.respond_to?(:close)

    tempfile.close
    tempfile.unlink
  rescue StandardError
    nil
  end
  private_class_method :cleanup_tempfile
end

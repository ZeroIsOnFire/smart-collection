# frozen_string_literal: true

require 'mini_magick'
require 'tempfile'

class ImageCropperService
  DEFAULT_MINIMUM_SIDE = ImageUpscalerService::DEFAULT_MINIMUM_SIDE

  def self.allowed_paths
    @allowed_paths ||= [
      Rails.public_path.join('uploads').to_s,
      (Rails.root.join('spec/fixtures').to_s if Rails.env.test?)
    ].compact.freeze
  end

  def self.crop(source_path, normalized_vertices, padding: 0.05, minimum_side: DEFAULT_MINIMUM_SIDE, upscale: {})
    return nil if normalized_vertices.blank?

    resolved_path = File.expand_path(source_path.to_s)
    unless allowed_paths.any? { |root| resolved_path.start_with?(root) }
      Rails.logger.error "ImageCropperService: path not allowed: #{resolved_path}"
      return nil
    end

    upscaled_file = ImageUpscalerService.upscale_if_needed(
      resolved_path,
      minimum_side: minimum_side,
      use_ai: upscale.fetch(:use_ai, true),
      local_fallback: upscale.fetch(:local_fallback, false)
    )
    working_path = upscaled_file&.path || resolved_path

    image = MiniMagick::Image.open(working_path)
    width = image.width
    height = image.height

    xs = normalized_vertices.map { |v| (v[:x] || v['x'] || 0) * width }
    ys = normalized_vertices.map { |v| (v[:y] || v['y'] || 0) * height }

    left = xs.min
    top = ys.min
    w = xs.max - left
    h = ys.max - top

    padding_w = w * padding
    padding_h = h * padding

    left = [0, left - padding_w].max
    top = [0, top - padding_h].max
    w = [width - left, w + (2 * padding_w)].min
    h = [height - top, h + (2 * padding_h)].min

    image.crop "#{w.to_i}x#{h.to_i}+#{left.to_i}+#{top.to_i}"

    output = Tempfile.new(['crop_', '.jpg'], Rails.root.join('tmp'))
    output.binmode
    image.write(output.path)
    output.rewind

    if [image.width, image.height].min < minimum_side
      upscaled_output = ImageUpscalerService.upscale_if_needed(
        output.path,
        minimum_side: minimum_side,
        use_ai: upscale.fetch(:use_ai, true),
        local_fallback: upscale.fetch(:local_fallback, false)
      )
      if upscaled_output
        cleanup_tempfile(output)
        return upscaled_output
      end

      ImageUpscalerService.resize_image_to_minimum_side!(image, minimum_side)
      image.write(output.path)
      output.rewind
    end

    output
  rescue ImageUpscalerService::UpscaleError
    raise
  rescue StandardError => e
    Rails.logger.error "Image Cropper Error: #{e.message}"
    nil
  ensure
    cleanup_tempfile(upscaled_file)
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

require "mini_magick"

class ImageCropperService
  def self.crop(source_path, normalized_vertices, padding: 0.05)
    return nil if normalized_vertices.blank?

    begin
      image = MiniMagick::Image.open(source_path)
      width = image.width
      height = image.height

      # normalized_vertices is an array of {x, y}
      xs = normalized_vertices.map { |v| (v[:x] || v["x"] || 0) * width }
      ys = normalized_vertices.map { |v| (v[:y] || v["y"] || 0) * height }

      left = xs.min
      top = ys.min
      w = xs.max - left
      h = ys.max - top

      # Add small padding
      padding_w = w * padding
      padding_h = h * padding
      
      left = [0, left - padding_w].max
      top = [0, top - padding_h].max
      w = [width - left, w + 2 * padding_w].min
      h = [height - top, h + 2 * padding_h].min

      # MiniMagick crop format: "widthxheight+x+y"
      image.crop "#{w.to_i}x#{h.to_i}+#{left.to_i}+#{top.to_i}"
      
      # We return a File object that CarrierWave can handle
      output_path = Rails.root.join('tmp', "crop_#{SecureRandom.hex(8)}.jpg")
      image.write output_path
      
      File.open(output_path)
    rescue => e
      Rails.logger.error "Image Cropper Error: #{e.message}"
      nil
    end
  end
end

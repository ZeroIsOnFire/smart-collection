# frozen_string_literal: true

require 'mini_magick'
require 'tempfile'

class ImageCropperService
  # Diretórios permitidos para leitura de imagens (proteção contra path traversal)
  def self.allowed_paths
    @allowed_paths ||= [
      Rails.public_path.join('uploads').to_s,
      (Rails.root.join('spec/fixtures').to_s if Rails.env.test?)
    ].compact.freeze
  end

  def self.crop(source_path, normalized_vertices, padding: 0.05)
    return nil if normalized_vertices.blank?

    # Proteção contra path traversal: garante que o arquivo está dentro dos diretórios permitidos
    resolved_path = File.expand_path(source_path.to_s)
    unless allowed_paths.any? { |root| resolved_path.start_with?(root) }
      Rails.logger.error "ImageCropperService: path não permitido: #{resolved_path}"
      return nil
    end

    begin
      image = MiniMagick::Image.open(resolved_path)
      width = image.width
      height = image.height

      # normalized_vertices is an array of {x, y}
      xs = normalized_vertices.map { |v| (v[:x] || v['x'] || 0) * width }
      ys = normalized_vertices.map { |v| (v[:y] || v['y'] || 0) * height }

      left = xs.min
      top = ys.min
      w = xs.max - left
      h = ys.max - top

      # Add small padding
      padding_w = w * padding
      padding_h = h * padding

      left = [0, left - padding_w].max
      top = [0, top - padding_h].max
      w = [width - left, w + (2 * padding_w)].min
      h = [height - top, h + (2 * padding_h)].min

      # MiniMagick crop format: "widthxheight+x+y"
      image.crop "#{w.to_i}x#{h.to_i}+#{left.to_i}+#{top.to_i}"

      # Upscale proporcional se a menor dimensão for menor que 500px
      if [image.width, image.height].min < 500
        image.resize '500x500^'
      end

      # Usar Tempfile para que o Ruby/OS gerencie a remoção automaticamente
      output = Tempfile.new(['crop_', '.jpg'], Rails.root.join('tmp'))
      output.binmode
      image.write(output.path)
      output.rewind
      output
    rescue StandardError => e
      Rails.logger.error "Image Cropper Error: #{e.message}"
      nil
    end
  end
end

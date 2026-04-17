class ColorDetectionService
  def self.detect(image_path)
    return nil unless File.exist?(image_path)

    begin
      image = MiniMagick::Image.open(image_path)
      
      # 1. Redução e Foco (Focamos no centro 50% para garantir que pegamos o carro)
      width, height = image.dimensions
      image.crop "50%x50%+#{width*0.25}+#{height*0.25}"
      image.resize "100x100" # Normaliza para análise estatística
      
      # 2. Quantização e Histograma (Aumentamos p/ 12 p/ isolar melhor o fundo)
      output = image.run do |cmd|
        cmd.colors 12
        cmd.define "histogram:unique-colors=true"
        cmd.format "%c"
        cmd << "histogram:info:-"
      end

      # 3. Parse do Histograma com Filtro de Fundo e Saliência
      lines = output.split("\n")
      dominant_hex = nil
      max_score = -1.0
      
      lines.each do |line|
        match = line.match(/^\s*(\d+):.*(#[0-9A-F]{6})/i)
        next unless match
        
        count = match[1].to_i
        hex = match[2]
        
        r = hex[1..2].to_i(16)
        g = hex[3..4].to_i(16)
        b = hex[5..6].to_i(16)
        
        # Filtro de Fundo: Se for muito claro (quase branco/gelo), penalizamos absurdamente
        # Isso evita que o fundo branco da mesa "ganhe" do carro amarelo
        is_background = r > 230 && g > 230 && b > 230
        
        max_c = [r, g, b].max
        min_c = [r, g, b].min
        chroma = max_c - min_c
        saturation = max_c == 0 ? 0 : (chroma.to_f / max_c)
        
        # Saliência: Cores saturadas ganham um peso MUITO maior
        # Se for fundo, a saturação é ignorada (0.01)
        vibrancy = is_background ? 0.01 : (saturation + 0.1)
        score = count * (vibrancy ** 2) # Exponencial para favorecer cores vivas
        
        if score > max_score
          max_score = score
          dominant_hex = hex
        end
      end

      return nil unless dominant_hex
      
      # Cores finais para o comparador
      r = dominant_hex[1..2].to_i(16)
      g = dominant_hex[3..4].to_i(16)
      b = dominant_hex[5..6].to_i(16)
      
      closest_color(r, g, b)
    rescue => e
      Rails.logger.error "ColorDetectionService Failed: #{e.message}"
      nil
    end
  end

  private

  def self.closest_color(r, g, b)
    min_distance = Float::INFINITY
    best_color = nil

    Car::COLORS.each do |name, hex|
      hr = hex[1..2].to_i(16)
      hg = hex[3..4].to_i(16)
      hb = hex[5..6].to_i(16)

      distance = Math.sqrt((r - hr)**2 + (g - hg)**2 + (b - hb)**2)
      
      if distance < min_distance
        min_distance = distance
        best_color = name
      end
    end

    best_color
  end
end

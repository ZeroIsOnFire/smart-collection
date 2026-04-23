require 'prawn'

class ExportPdfService
  def initialize(user, cars)
    @user = user
    @cars = cars
    @temp_files = []
  end

  def generate
    Prawn::Fonts::AFM.hide_m17n_warning = true
    pdf_content = Prawn::Document.new(page_size: 'A4', margin: [40, 30, 40, 30]) do |pdf|
      # --- Header Premium ---
      pdf.fill_color "1E293B" # Slate escuro
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, 100
      
      pdf.fill_color "FFFFFF"
      pdf.font "Helvetica"
      
      pdf.move_down 30
      safe_title = "CATÁLOGO DE COLEÇÃO".encode("Windows-1252", invalid: :replace, undef: :replace, replace: "") rescue "CATALOGO DE COLECAO"
      pdf.text safe_title, size: 10, style: :bold, align: :center, character_spacing: 2
      
      pdf.move_down 5
      # Tentar converter nome do usuário para Windows-1252 para evitar crash no Prawn
      safe_user = "#{@user.name.presence || 'Usuário'}".encode("Windows-1252", invalid: :replace, undef: :replace, replace: "") rescue "USUARIO"
      pdf.text safe_user.upcase, size: 24, style: :bold, align: :center
      
      pdf.move_down 5
      pdf.fill_color "94A3B8"
      pdf.text "Gerado em: #{Time.current.strftime('%d/%m/%Y %H:%M')}", size: 9, align: :center
      pdf.text "Total de itens: #{@cars.count}", size: 9, align: :center
      
      pdf.move_down 60

      # --- Grid Settings ---
      columns = 3
      gutter = 20
      col_width = (pdf.bounds.width - (gutter * (columns - 1))) / columns
      card_height = 210
      
      y_start = pdf.cursor
      
      @cars.each_with_index do |car, index|
        col = index % columns
        
        if col == 0 && index > 0 && y_start - card_height < pdf.bounds.bottom
          pdf.start_new_page
          y_start = pdf.cursor
        end
        
        x = col * (col_width + gutter)
        
        pdf.bounding_box([x, y_start], width: col_width, height: card_height) do
          # Sombra sutil (retângulo deslocado)
          pdf.fill_color "F1F5F9"
          pdf.fill_rounded_rectangle [2, pdf.bounds.top - 2], col_width, card_height, 10
          
          # Card background
          pdf.fill_color "FFFFFF"
          pdf.fill_rounded_rectangle [0, pdf.bounds.top], col_width, card_height, 10
          
          # Border
          pdf.stroke_color "E2E8F0"
          pdf.line_width = 0.5
          pdf.stroke_rounded_rectangle [0, pdf.bounds.top], col_width, card_height, 10
          
          # --- Image Area ---
          img_height = 115
          pdf.bounding_box([0, pdf.bounds.top], width: col_width, height: img_height) do
            # Clip image to rounded corners top
            pdf.fill_color "F8FAFC"
            pdf.fill_rounded_rectangle [0, pdf.bounds.top], col_width, img_height, 10
            
            if car.photo? && File.exist?(car.photo.path)
              begin
                photo_path = car.photo.path
                image = MiniMagick::Image.open(photo_path)
                real_type = image.type.downcase
                
                if !['jpeg', 'png'].include?(real_type)
                  temp_jpg = Tempfile.new(['photo_convert', '.jpg'])
                  temp_jpg.binmode
                  @temp_files << temp_jpg
                  image.format "jpg"
                  image.write temp_jpg.path
                  photo_path = temp_jpg.path
                  prawn_type = :jpg
                else
                  prawn_type = (real_type == 'jpeg' ? :jpg : :png)
                end

                pdf.image photo_path, fit: [col_width - 10, img_height - 10], position: :center, vposition: :center, type: prawn_type
              rescue StandardError => e
                pdf.move_down (img_height / 2) - 5
                pdf.fill_color "94A3B8"
                pdf.text "Sem Imagem", align: :center, size: 8
              end
            else
              pdf.move_down (img_height / 2) - 5
              pdf.fill_color "94A3B8"
              pdf.text "Sem Foto", align: :center, size: 8
            end
          end
          
          # --- Text Area ---
          text_box_y = pdf.bounds.top - img_height - 10
          pdf.bounding_box([8, text_box_y], width: col_width - 16, height: card_height - img_height - 10) do
            # Name
            pdf.fill_color "0F172A"
            safe_name = car.name.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "") rescue car.name
            pdf.text safe_name, size: 9, style: :bold, align: :center, overflow: :truncate
            
            pdf.move_down 4
            
            # Details
            details = []
            details << car.brand if car.brand.present?
            details << car.year.to_s if car.year.present?
            details << car.size if car.size.present?
            
            safe_details = details.join(" • ").encode("Windows-1252", invalid: :replace, undef: :replace, replace: "") rescue details.join(" • ")
            pdf.fill_color "64748B"
            pdf.text safe_details, size: 7, align: :center, overflow: :truncate
            
            # Color
            if car.color.present?
              pdf.move_down 5
              color_hex = Car::COLORS[car.color] || "#CCCCCC"
              prawn_color = color_hex.delete('#')
              
              color_text = car.color.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "") rescue car.color
              text_width = pdf.width_of(color_text, size: 7)
              total_width = 12 + text_width
              start_x = (pdf.bounds.width - total_width) / 2
              
              # Círculo de cor
              pdf.fill_color prawn_color
              pdf.fill_circle [start_x + 4, pdf.cursor - 3.5], 3.5
              pdf.stroke_color "DEE2E6"
              pdf.line_width = 0.5
              pdf.stroke_circle [start_x + 4, pdf.cursor - 3.5], 3.5
              
              # Texto da cor
              pdf.fill_color "64748B"
              pdf.draw_text color_text, at: [start_x + 12, pdf.cursor - 6], size: 7
              
              # IMPORTANTE: Avançar o cursor manualmente após usar draw_text/fill_circle
              pdf.move_down 10
            end

            # Observations
            if car.observations.present?
              pdf.move_down 2 # Pequeno ajuste
              safe_obs = car.observations.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "") rescue car.observations
              pdf.fill_color "94A3B8"
              
              # Aumentamos a altura disponível para aproveitar o espaço do card
              pdf.text_box safe_obs, 
                           at: [0, pdf.cursor], 
                           width: pdf.bounds.width, 
                           height: 40, # Mais espaço para observações
                           size: 6.5, 
                           align: :center, 
                           overflow: :truncate, 
                           font_style: :italic,
                           leading: 1
            end
          end
        end
        
        if col == columns - 1
          y_start -= (card_height + gutter)
        end
      end
    end.render
    
    @temp_files.each { |f| f.close; f.unlink } rescue nil
    pdf_content
  end
end

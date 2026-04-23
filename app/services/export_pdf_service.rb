require 'prawn'

class ExportPdfService
  def initialize(user, cars)
    @user = user
    @cars = cars
  end

  def generate
    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header
      pdf.fill_color "333333"
      pdf.font "Helvetica"
      
      pdf.text "Coleção de #{@user.name.presence || 'Usuário'}", size: 24, style: :bold, align: :center
      pdf.move_down 10
      pdf.text "Total de itens: #{@cars.count}", size: 12, align: :center, color: "666666"
      pdf.move_down 30

      # Grid variables
      columns = 2
      col_width = (pdf.bounds.width - 20) / columns
      row_height = 250
      
      y_start = pdf.cursor
      
      @cars.each_with_index do |car, index|
        col = index % columns
        
        # Start a new page if the current row won't fit
        if col == 0 && index > 0 && y_start - row_height < pdf.bounds.bottom
          pdf.start_new_page
          y_start = pdf.cursor
        end
        
        x = col * (col_width + 20)
        
        # Draw Card
        pdf.bounding_box([x, y_start], width: col_width, height: row_height - 20) do
          pdf.stroke_color "DDDDDD"
          pdf.stroke_bounds
          
          pdf.move_down 10
          
          # Photo
          if car.photo? && File.exist?(car.photo.path)
            begin
              pdf.image car.photo.path, fit: [col_width - 20, 130], position: :center
            rescue StandardError => e
              pdf.move_down 50
              pdf.text "Imagem inválida", align: :center, color: "999999", size: 10
              pdf.move_down 65
            end
          else
            pdf.move_down 50
            pdf.text "Sem Imagem", align: :center, color: "999999", size: 10
            pdf.move_down 65
          end
          
          # Info section
          pdf.y = pdf.bounds.top - 150
          
          pdf.fill_color "000000"
          pdf.text car.name, size: 14, style: :bold, align: :center, overflow: :truncate
          pdf.move_down 5
          
          details = []
          details << car.brand if car.brand.present?
          details << car.year.to_s if car.year.present?
          details << car.size if car.size.present?
          
          pdf.fill_color "666666"
          pdf.text details.join(" • "), size: 10, align: :center
        end
        
        # Move y_start down after the last column of the row
        if col == columns - 1
          y_start -= row_height
        end
      end
    end.render
  end
end

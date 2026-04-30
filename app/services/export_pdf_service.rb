# frozen_string_literal: true

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
      pdf.fill_color '1E293B' # Slate escuro
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, 80

      pdf.fill_color 'FFFFFF'
      pdf.font 'Helvetica'

      pdf.move_down 20
      raw_title = I18n.t('export_pdf.title')
      safe_title = begin
        raw_title.encode('Windows-1252', invalid: :replace, undef: :replace,
                                         replace: '')
      rescue StandardError
        'CATALOGO DE COLECAO'
      end
      pdf.text safe_title, size: 8, style: :bold, align: :center, character_spacing: 2

      pdf.move_down 3
      # Tentar converter nome do usuário para Windows-1252 para evitar crash no Prawn
      user_name = @user.name.presence || I18n.t('export_pdf.user_placeholder')
      safe_user = begin
        user_name.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '')
      rescue StandardError
        'USUARIO'
      end
      pdf.text safe_user.upcase, size: 20, style: :bold, align: :center

      pdf.move_down 3
      pdf.fill_color '94A3B8'
      meta_info = I18n.t('export_pdf.meta_info', date: Time.current.strftime('%d/%m/%Y %H:%M'), count: @cars.count)
      pdf.text meta_info, size: 8, align: :center

      pdf.move_down 40

      # --- Grid Settings ---
      columns = 4
      gutter = 12
      col_width = (pdf.bounds.width - (gutter * (columns - 1))) / columns
      card_height = 185
      img_height = 95

      y_start = pdf.cursor

      @cars.each_with_index do |car, index|
        col = index % columns

        if col.zero? && index.positive? && y_start - card_height < pdf.bounds.bottom
          pdf.start_new_page
          y_start = pdf.cursor
        end

        x = col * (col_width + gutter)

        pdf.bounding_box([x, y_start], width: col_width, height: card_height) do
          # Sombra sutil (retângulo deslocado)
          pdf.fill_color 'F1F5F9'
          pdf.fill_rounded_rectangle [2, pdf.bounds.top - 2], col_width, card_height, 10

          # Card background
          pdf.fill_color 'FFFFFF'
          pdf.fill_rounded_rectangle [0, pdf.bounds.top], col_width, card_height, 10

          # Border
          pdf.stroke_color 'E2E8F0'
          pdf.line_width = 0.5
          pdf.stroke_rounded_rectangle [0, pdf.bounds.top], col_width, card_height, 10

          # --- Image Area ---
          pdf.bounding_box([0, pdf.bounds.top], width: col_width, height: img_height) do
            # Clip image to rounded corners top
            pdf.fill_color 'F8FAFC'
            pdf.fill_rounded_rectangle [0, pdf.bounds.top], col_width, img_height, 10

            if car.photo? && File.exist?(car.photo.path)
              begin
                photo_path = car.photo.path
                image = MiniMagick::Image.open(photo_path)
                real_type = image.type.downcase

                if %w[jpeg png].include?(real_type)
                  prawn_type = (real_type == 'jpeg' ? :jpg : :png)
                else
                  temp_jpg = Tempfile.new(['photo_convert', '.jpg'])
                  temp_jpg.binmode
                  @temp_files << temp_jpg
                  image.format 'jpg'
                  image.write temp_jpg.path
                  photo_path = temp_jpg.path
                  prawn_type = :jpg
                end

                pdf.image photo_path, fit: [col_width - 10, img_height - 10], position: :center, vposition: :center,
                                      type: prawn_type
              rescue StandardError
                pdf.move_down (img_height / 2) - 5
                pdf.fill_color '94A3B8'
                pdf.text I18n.t('export_pdf.no_image'), align: :center, size: 8
              end
            else
              pdf.move_down (img_height / 2) - 5
              pdf.fill_color '94A3B8'
              pdf.text I18n.t('export_pdf.no_photo'), align: :center, size: 8
            end
          end

          # --- Text Area ---
          text_box_y = pdf.bounds.top - img_height - 8
          pdf.bounding_box([6, text_box_y], width: col_width - 12, height: card_height - img_height - 8) do
            # Name
            pdf.fill_color '0F172A'
            safe_name = begin
              car.name.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '')
            rescue StandardError
              car.name
            end
            pdf.text safe_name, size: 8.5, style: :bold, align: :center, overflow: :truncate

            pdf.move_down 3

            # Details
            details = []
            details << car.brand if car.brand?
            details << car.year.to_s if car.year?
            details << car.size if car.size?

            safe_details = begin
              details.join(' • ').encode('Windows-1252', invalid: :replace, undef: :replace,
                                                         replace: '')
            rescue StandardError
              details.join(' • ')
            end
            pdf.fill_color '64748B'
            pdf.text safe_details, size: 7, align: :center, overflow: :truncate

            # Color
            if car.color?
              pdf.move_down 5
              color_hex = Car::COLORS[car.color] || '#CCCCCC'
              prawn_color = color_hex.delete('#')

              color_text = begin
                car.color.encode('Windows-1252', invalid: :replace, undef: :replace,
                                                 replace: '')
              rescue StandardError
                car.color
              end
              text_width = pdf.width_of(color_text, size: 7)
              total_width = 12 + text_width
              start_x = (pdf.bounds.width - total_width) / 2

              # Círculo de cor
              pdf.fill_color prawn_color
              pdf.fill_circle [start_x + 4, pdf.cursor - 3.5], 3.5
              pdf.stroke_color 'DEE2E6'
              pdf.line_width = 0.5
              pdf.stroke_circle [start_x + 4, pdf.cursor - 3.5], 3.5

              # Texto da cor
              pdf.fill_color '64748B'
              pdf.draw_text color_text, at: [start_x + 12, pdf.cursor - 6], size: 7

              # IMPORTANTE: Avançar o cursor manualmente após usar draw_text/fill_circle
              pdf.move_down 10
            end

            # Observations
            if car.observations?
              pdf.move_down 2 # Pequeno ajuste
              clean_obs = car.observations.to_s.squish
              safe_obs = begin
                clean_obs.encode('Windows-1252', invalid: :replace, undef: :replace,
                                                 replace: '')
              rescue StandardError
                clean_obs
              end
              pdf.fill_color '94A3B8'

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

        y_start -= (card_height + gutter) if col == columns - 1
      end

      # --- Footer com Logo e numeração ---
      pdf.repeat(:all) do
        pdf.stroke_color 'E2E8F0'
        pdf.line_width = 0.5
        pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.right, at: -5

        # Logo no Rodapé (Esquerda)
        logo_path = Rails.root.join('public', 'logo', 'logo.png')
        if File.exist?(logo_path)
          pdf.image logo_path, at: [pdf.bounds.left, -17], height: 12
          pdf.fill_color '94A3B8'
          pdf.draw_text 'SmartCollection', at: [pdf.bounds.left + 20, -26], size: 8, style: :bold
        else
          pdf.fill_color '3B82F6'
          pdf.fill_circle [pdf.bounds.left + 10, -20.5], 4
          pdf.fill_color '1D4ED8'
          pdf.fill_circle [pdf.bounds.left + 15, -24.5], 4

          pdf.fill_color '94A3B8'
          pdf.draw_text 'Smart', at: [pdf.bounds.left + 25, -25], size: 8, style: :bold
          pdf.fill_color '3B82F6'
          pdf.draw_text 'Collection', at: [pdf.bounds.left + 48, -25], size: 8, style: :bold
        end
      end

      page_string = I18n.t('export_pdf.page_info', page: '<page>', total: '<total>')
      pdf.number_pages page_string,
                       at: [pdf.bounds.left, -18.5],
                       size: 8,
                       color: '94A3B8',
                       align: :right
    end.render

    begin
      @temp_files.each do |f|
        f.close
        f.unlink
      end
    rescue StandardError
      nil
    end
    pdf_content
  end
end

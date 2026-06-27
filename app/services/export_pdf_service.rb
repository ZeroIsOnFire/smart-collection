# frozen_string_literal: true

require 'prawn'

class ExportPdfService
  CATALOG_COLUMNS = 2
  CATALOG_GUTTER = 18
  CARD_HEIGHT = 265
  CARD_IMAGE_HEIGHT = 150
  COLORS = {
    navy: '1F2933',
    teal: '2F6F68',
    teal_dark: '214F4A',
    teal_soft: 'E8F1EF',
    muted: '6B7280',
    text_muted: '6F6256',
    text_soft: '8E8174',
    soft: 'F6F1E8',
    line: 'D7C7B2',
    gold: 'A56D32',
    white: 'FFFFFF'
  }.freeze

  def initialize(user, cars, generated_at: Time.current)
    @user = user
    @cars = cars.to_a
    @generated_at = generated_at
    @temp_files = []
  end

  def generate
    Prawn::Fonts::AFM.hide_m17n_warning = true

    Prawn::Document.new(page_size: 'A4', margin: [44, 34, 44, 34]) do |pdf|
      pdf.font 'Helvetica'

      draw_cover_page(pdf)
      pdf.start_new_page
      draw_catalog_pages(pdf)
      draw_footer(pdf)
      draw_page_numbers(pdf)
    end.render
  ensure
    cleanup_temp_files
  end

  private

  def draw_cover_page(pdf)
    draw_cover_background(pdf)
    draw_cover_card(pdf)
    draw_cover_photo_strip(pdf)
    draw_cover_highlights(pdf)
  end

  def draw_cover_background(pdf)
    pdf.canvas do
      pdf.fill_color COLORS[:soft]
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, pdf.bounds.height

      pdf.fill_color COLORS[:teal_dark]
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, 250

      pdf.fill_color COLORS[:teal]
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top - 250], pdf.bounds.width, 26

      pdf.fill_color COLORS[:gold]
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top - 276], pdf.bounds.width, 3

      pdf.fill_color COLORS[:teal_soft]
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.bottom + 54], pdf.bounds.width, 92
    end
  end

  def draw_cover_card(pdf)
    card_x = 34
    card_y = pdf.bounds.top - 112
    card_width = pdf.bounds.width - 68
    card_height = 260

    pdf.fill_color 'C8B99F'
    pdf.transparent(0.25) do
      pdf.fill_rounded_rectangle [card_x + 5, card_y - 5], card_width, card_height, 8
    end

    pdf.fill_color COLORS[:white]
    pdf.fill_rounded_rectangle [card_x, card_y], card_width, card_height, 8

    pdf.stroke_color COLORS[:line]
    pdf.line_width = 0.8
    pdf.stroke_rounded_rectangle [card_x, card_y], card_width, card_height, 8

    content_x = card_x + 28
    content_y = card_y - 30
    content_width = card_width - 56
    summary_width = 132
    gap = 28

    pdf.bounding_box([content_x, content_y], width: content_width - summary_width - gap, height: card_height - 52) do
      draw_cover_title_block(pdf)
    end

    pdf.bounding_box([content_x + content_width - summary_width, content_y - 32],
                     width: summary_width,
                     height: 96) do
      draw_collection_summary(pdf)
    end
  end

  def draw_cover_title_block(pdf)
    pdf.fill_color COLORS[:gold]
    pdf.text safe_text(I18n.t('export_pdf.eyebrow')),
             size: 8.5,
             style: :bold,
             character_spacing: 1.8
    pdf.move_down 12

    pdf.fill_color COLORS[:teal_dark]
    pdf.text safe_text(I18n.t('export_pdf.title')),
             size: 28,
             style: :bold,
             leading: 2
    pdf.move_down 8

    pdf.fill_color COLORS[:muted]
    pdf.text safe_text(collection_owner_name), size: 12
    pdf.move_down 18

    pdf.stroke_color COLORS[:gold]
    pdf.line_width = 1.2
    pdf.stroke_horizontal_line 0, 120, at: pdf.cursor
  end

  def draw_collection_summary(pdf)
    metric = collection_metrics.first
    card_width = pdf.bounds.width
    card_height = pdf.bounds.height

    pdf.bounding_box([0, pdf.cursor], width: card_width, height: card_height) do
      pdf.fill_color COLORS[:teal_soft]
      pdf.fill_rounded_rectangle [0, pdf.bounds.top], card_width, card_height, 8
      pdf.stroke_color 'B7D1CC'
      pdf.line_width = 0.6
      pdf.stroke_rounded_rectangle [0, pdf.bounds.top], card_width, card_height, 8

      pdf.move_down 18
      pdf.fill_color COLORS[:teal_dark]
      pdf.text safe_text(metric[:value]), size: 26, style: :bold, align: :center
      pdf.move_down 4
      pdf.fill_color COLORS[:muted]
      pdf.text safe_text(metric[:label]), size: 8, align: :center, character_spacing: 0.6
    end
  end

  def draw_cover_photo_strip(pdf)
    strip_y = pdf.bounds.top - 405
    strip_x = 54
    strip_width = pdf.bounds.width - 108
    strip_height = 126
    images = @cars.first(3).filter_map { |car| prepared_photo(car) }

    pdf.fill_color COLORS[:white]
    pdf.fill_rounded_rectangle [strip_x, strip_y], strip_width, strip_height, 8
    pdf.stroke_color COLORS[:line]
    pdf.line_width = 0.7
    pdf.stroke_rounded_rectangle [strip_x, strip_y], strip_width, strip_height, 8

    return draw_cover_empty_strip(pdf, strip_x, strip_y, strip_width, strip_height) if images.empty?

    gap = 10
    image_width = (strip_width - 36 - (gap * 2)) / 3
    image_height = strip_height - 32
    image_y = strip_y - 16

    images.each_with_index do |image_data, index|
      image_x = strip_x + 18 + (index * (image_width + gap))
      pdf.bounding_box([image_x, image_y], width: image_width, height: image_height) do
        pdf.fill_color COLORS[:soft]
        pdf.fill_rounded_rectangle [0, pdf.bounds.top], image_width, image_height, 6
        pdf.image image_data[:path],
                  fit: [image_width - 12, image_height - 12],
                  position: :center,
                  vposition: :center,
                  type: image_data[:type]
      rescue StandardError
        draw_cover_photo_placeholder(pdf, image_width, image_height)
      end
    end
  end

  def draw_cover_empty_strip(pdf, strip_x, strip_y, strip_width, strip_height)
    pdf.bounding_box([strip_x + 18, strip_y - 26], width: strip_width - 36, height: strip_height - 40) do
      pdf.fill_color COLORS[:teal_soft]
      pdf.fill_rounded_rectangle [0, pdf.bounds.top], pdf.bounds.width, pdf.bounds.height, 6
      pdf.move_down 28
      pdf.fill_color COLORS[:muted]
      pdf.text safe_text(I18n.t('export_pdf.empty_collection')), size: 10, align: :center
    end
  end

  def draw_cover_photo_placeholder(pdf, image_width, image_height)
    pdf.fill_color COLORS[:soft]
    pdf.fill_rounded_rectangle [0, pdf.bounds.top], image_width, image_height, 6
    pdf.move_down (image_height / 2) - 8
    pdf.fill_color COLORS[:muted]
    pdf.text safe_text(I18n.t('export_pdf.no_photo')), size: 8, align: :center
  end

  def draw_cover_highlights(pdf)
    pdf.bounding_box([54, pdf.bounds.bottom + 178], width: pdf.bounds.width - 108, height: 74) do
      pdf.fill_color COLORS[:teal_dark]
      pdf.text safe_text(I18n.t('export_pdf.cover_description')), size: 10, align: :center, leading: 4
      pdf.move_down 14
      pdf.fill_color COLORS[:gold]
      pdf.text safe_text(I18n.t('export_pdf.generated_at',
                                date: I18n.l(@generated_at, format: :export_timestamp))),
               size: 8.5,
               style: :bold,
               align: :center,
               character_spacing: 1
    end
  end

  def draw_catalog_pages(pdf)
    draw_catalog_header(pdf)

    if @cars.empty?
      draw_empty_catalog(pdf)
      return
    end

    col_width = (pdf.bounds.width - (CATALOG_GUTTER * (CATALOG_COLUMNS - 1))) / CATALOG_COLUMNS
    y_start = pdf.cursor

    @cars.each_with_index do |car, index|
      col = index % CATALOG_COLUMNS

      if col.zero? && index.positive? && y_start - CARD_HEIGHT < pdf.bounds.bottom
        pdf.start_new_page
        draw_catalog_header(pdf)
        y_start = pdf.cursor
      end

      x = col * (col_width + CATALOG_GUTTER)
      draw_catalog_card(pdf, car, x, y_start, col_width)
      y_start -= (CARD_HEIGHT + CATALOG_GUTTER) if col == CATALOG_COLUMNS - 1
    end
  end

  def draw_catalog_header(pdf)
    pdf.fill_color COLORS[:navy]
    pdf.text safe_text(I18n.t('export_pdf.catalog_section')), size: 15, style: :bold
    pdf.move_down 5
    pdf.fill_color COLORS[:muted]
    pdf.text safe_text(I18n.t('export_pdf.meta_info',
                              date: I18n.l(@generated_at, format: :export_timestamp),
                              count: @cars.count)),
             size: 8.5
    pdf.move_down 20
  end

  def draw_empty_catalog(pdf)
    pdf.move_down 110
    pdf.fill_color 'D7C7B2'
    pdf.fill_circle [pdf.bounds.width / 2, pdf.cursor], 34
    pdf.move_down 48
    pdf.fill_color COLORS[:muted]
    pdf.text safe_text(I18n.t('export_pdf.empty_collection')), size: 11, align: :center
  end

  def draw_catalog_card(pdf, car, x_position, y_start, col_width)
    pdf.bounding_box([x_position, y_start], width: col_width, height: CARD_HEIGHT) do
      draw_card_frame(pdf, col_width)
      draw_photo_area(pdf, car, col_width)
      draw_card_body(pdf, car, col_width)
    end
  end

  def draw_card_frame(pdf, col_width)
    pdf.fill_color 'E2E8F0'
    pdf.transparent(0.35) do
      pdf.fill_rounded_rectangle [3, pdf.bounds.top - 3], col_width, CARD_HEIGHT, 10
    end

    pdf.fill_color COLORS[:white]
    pdf.fill_rounded_rectangle [0, pdf.bounds.top], col_width, CARD_HEIGHT, 10
    pdf.stroke_color COLORS[:line]
    pdf.line_width = 0.6
    pdf.stroke_rounded_rectangle [0, pdf.bounds.top], col_width, CARD_HEIGHT, 10
  end

  def draw_photo_area(pdf, car, col_width)
    pdf.bounding_box([0, pdf.bounds.top], width: col_width, height: CARD_IMAGE_HEIGHT) do
      pdf.fill_color COLORS[:soft]
      pdf.fill_rounded_rectangle [0, pdf.bounds.top], col_width, CARD_IMAGE_HEIGHT, 10

      image_data = prepared_photo(car)

      if image_data
        pdf.image image_data[:path],
                  fit: [col_width - 16, CARD_IMAGE_HEIGHT - 16],
                  position: :center,
                  vposition: :center,
                  type: image_data[:type]
        draw_ai_photo_badge(pdf, col_width) if car.photo_upscaled_by_ai?
      else
        pdf.move_down (CARD_IMAGE_HEIGHT / 2) - 8
        pdf.fill_color COLORS[:text_soft]
        pdf.text safe_text(I18n.t('export_pdf.no_photo')), align: :center, size: 8.5
      end
    rescue StandardError
      pdf.move_down (CARD_IMAGE_HEIGHT / 2) - 8
      pdf.fill_color COLORS[:text_soft]
      pdf.text safe_text(I18n.t('export_pdf.no_image')), align: :center, size: 8.5
    end
  end

  def draw_card_body(pdf, car, col_width)
    pdf.bounding_box([12, pdf.bounds.top - CARD_IMAGE_HEIGHT - 12],
                     width: col_width - 24,
                     height: CARD_HEIGHT - CARD_IMAGE_HEIGHT - 18) do
      pdf.fill_color COLORS[:teal_dark]
      pdf.text safe_text(car.name), size: 11, style: :bold, overflow: :truncate
      pdf.move_down 8

      draw_metadata_row(pdf, I18n.t('export_pdf.metadata.brand'), car.brand) if car.brand?
      draw_metadata_row(pdf, I18n.t('export_pdf.metadata.year'), car.year.to_s) if car.year?
      draw_metadata_row(pdf, I18n.t('export_pdf.metadata.scale'), car.size) if car.size?
      draw_color_row(pdf, car) if car.color?

      return unless car.observations?

      pdf.move_down 7
      pdf.fill_color COLORS[:text_soft]
      pdf.text_box safe_text(car.observations.to_s.squish),
                   at: [0, pdf.cursor],
                   width: pdf.bounds.width,
                   height: 28,
                   size: 7,
                   overflow: :truncate,
                   font_style: :italic,
                   leading: 1
    end
  end

  def draw_metadata_row(pdf, label, value)
    pdf.fill_color COLORS[:text_muted]
    pdf.formatted_text [
      { text: "#{safe_text(label)}: ", styles: [:bold], color: COLORS[:teal_dark] },
      { text: safe_text(value), color: COLORS[:text_muted] }
    ], size: 8, leading: 1
  end

  def draw_color_row(pdf, car)
    color_hex = Car::COLORS[car.color] || '#CCCCCC'
    prawn_color = color_hex.delete('#')
    y = pdf.cursor - 4

    pdf.fill_color COLORS[:teal_dark]
    pdf.draw_text "#{safe_text(I18n.t('export_pdf.metadata.color'))}:",
                  at: [0, y - 2],
                  size: 8,
                  style: :bold

    label_width = pdf.width_of("#{safe_text(I18n.t('export_pdf.metadata.color'))}:", size: 8, style: :bold)
    pdf.fill_color prawn_color
    pdf.fill_circle [label_width + 9, y], 4
    pdf.stroke_color COLORS[:line]
    pdf.line_width = 0.5
    pdf.stroke_circle [label_width + 9, y], 4

    pdf.fill_color COLORS[:text_muted]
    pdf.draw_text safe_text(car.color), at: [label_width + 18, y - 3], size: 8
    pdf.move_down 14
  end

  def prepared_photo(car)
    path = displayed_photo_path(car)
    return if path.blank? || !File.exist?(path)

    image = MiniMagick::Image.open(path)
    real_type = image.type.downcase
    return { path: path, type: (real_type == 'jpeg' ? :jpg : :png) } if %w[jpeg png].include?(real_type)

    temp_jpg = Tempfile.new(['photo_convert', '.jpg'])
    temp_jpg.binmode
    @temp_files << temp_jpg
    image.format 'jpg'
    image.write temp_jpg.path

    { path: temp_jpg.path, type: :jpg }
  end

  def displayed_photo_path(car)
    return car.enhanced_photo.path if car.photo_upscaled_by_ai? && car.enhanced_photo?
    return car.photo.path if car.photo?

    nil
  end

  def draw_footer(pdf)
    pdf.repeat(:all) do
      pdf.stroke_color COLORS[:line]
      pdf.line_width = 0.5
      pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.right, at: -5

      logo_path = Rails.public_path.join('logo/logo.png')
      if File.exist?(logo_path)
        pdf.image logo_path, at: [pdf.bounds.left, -10], height: 24
        pdf.fill_color '94A3B8'
        pdf.draw_text 'SmartCollection', at: [pdf.bounds.left + 32, -26], size: 8, style: :bold
      else
        pdf.fill_color COLORS[:teal]
        pdf.fill_circle [pdf.bounds.left + 10, -20.5], 4
        pdf.fill_color COLORS[:gold]
        pdf.fill_circle [pdf.bounds.left + 15, -24.5], 4

        pdf.fill_color '94A3B8'
        pdf.draw_text 'Smart', at: [pdf.bounds.left + 25, -25], size: 8, style: :bold
        pdf.fill_color COLORS[:teal]
        pdf.draw_text 'Collection', at: [pdf.bounds.left + 48, -25], size: 8, style: :bold
      end
    end
  end

  def draw_page_numbers(pdf)
    page_string = I18n.t('export_pdf.page_info', page: '<page>', total: '<total>')
    pdf.number_pages page_string,
                     at: [pdf.bounds.left, -18.5],
                     size: 8,
                     color: '94A3B8',
                     align: :right
  end

  def draw_ai_photo_badge(pdf, col_width)
    badge_label = I18n.t('export_pdf.ai_photo_badge')
    badge_width = 32
    badge_height = 14
    x_position = col_width - badge_width - 10
    y_position = pdf.bounds.top - 10
    text_width = pdf.width_of(badge_label, size: 7, style: :bold)
    text_x_position = x_position + ((badge_width - text_width) / 2)

    pdf.fill_color COLORS[:teal]
    pdf.transparent(0.78) do
      pdf.fill_rounded_rectangle [x_position, y_position], badge_width, badge_height, 4
    end
    pdf.fill_color COLORS[:white]
    pdf.draw_text badge_label,
                  at: [text_x_position, y_position - 9],
                  size: 7,
                  style: :bold
  end

  def collection_metrics
    [
      { label: I18n.t('export_pdf.summary.items'), value: @cars.count.to_s }
    ]
  end

  def collection_owner_name
    @user.name.presence || I18n.t('export_pdf.user_placeholder')
  end

  def safe_text(value, fallback = '')
    value.to_s.encode('Windows-1252', invalid: :replace, undef: :replace, replace: fallback)
  rescue StandardError
    fallback
  end

  def cleanup_temp_files
    @temp_files.each do |file|
      file.close
      file.unlink
    rescue StandardError
      nil
    end
  end
end

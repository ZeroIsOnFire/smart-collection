# frozen_string_literal: true

require 'prawn'
require 'mini_magick'

class WishlistPdfExportService
  CATALOG_COLUMNS = 2
  CATALOG_GUTTER = 18
  CARD_HEIGHT = 245
  CARD_IMAGE_HEIGHT = 136
  COLORS = ExportPdfService::COLORS

  def initialize(user, wishlist_items, generated_at: Time.current)
    @user = user
    @wishlist_items = wishlist_items.to_a
    @generated_at = generated_at
    @temp_files = []
  end

  def generate
    Prawn::Fonts::AFM.hide_m17n_warning = true

    Prawn::Document.new(page_size: 'A4', margin: [44, 34, 44, 34]) do |pdf|
      pdf.font 'Helvetica'
      draw_catalog_pages(pdf)
      draw_footer(pdf)
      draw_page_numbers(pdf)
    end.render
  ensure
    cleanup_temp_files
  end

  private

  def draw_catalog_pages(pdf)
    draw_catalog_header(pdf)

    if @wishlist_items.empty?
      draw_empty_catalog(pdf)
      return
    end

    col_width = (pdf.bounds.width - (CATALOG_GUTTER * (CATALOG_COLUMNS - 1))) / CATALOG_COLUMNS
    y_start = pdf.cursor

    @wishlist_items.each_with_index do |item, index|
      col = index % CATALOG_COLUMNS

      if col.zero? && index.positive? && y_start - CARD_HEIGHT < pdf.bounds.bottom
        pdf.start_new_page
        draw_catalog_header(pdf)
        y_start = pdf.cursor
      end

      x = col * (col_width + CATALOG_GUTTER)
      draw_catalog_card(pdf, item, x, y_start, col_width)
      y_start -= (CARD_HEIGHT + CATALOG_GUTTER) if col == CATALOG_COLUMNS - 1
    end
  end

  def draw_catalog_header(pdf)
    header_height = 92

    pdf.fill_color COLORS[:teal_dark]
    pdf.fill_rounded_rectangle [0, pdf.cursor], pdf.bounds.width, header_height, 8
    pdf.fill_color COLORS[:teal]
    pdf.fill_rectangle [0, pdf.cursor - header_height + 14], pdf.bounds.width, 14
    pdf.fill_color COLORS[:gold]
    pdf.fill_rectangle [0, pdf.cursor - header_height], pdf.bounds.width, 3

    pdf.fill_color COLORS[:white]
    pdf.draw_text safe_text(I18n.t('wishlist_exports.pdf.header_title', name: owner_name)),
                  at: [18, pdf.cursor - 34],
                  size: 20,
                  style: :bold
    pdf.fill_color 'E8F1EF'
    pdf.draw_text safe_text(I18n.t('wishlist_exports.pdf.meta_info',
                                   count: @wishlist_items.count,
                                   date: I18n.l(@generated_at, format: :export_timestamp))),
                  at: [18, pdf.cursor - 62],
                  size: 9

    pdf.move_down 120
  end

  def draw_empty_catalog(pdf)
    pdf.move_down 110
    pdf.fill_color COLORS[:line]
    pdf.fill_circle [pdf.bounds.width / 2, pdf.cursor], 34
    pdf.move_down 48
    pdf.fill_color COLORS[:muted]
    pdf.text safe_text(I18n.t('wishlist_exports.pdf.empty')), size: 11, align: :center
  end

  def draw_catalog_card(pdf, item, x_position, y_start, col_width)
    pdf.bounding_box([x_position, y_start], width: col_width, height: CARD_HEIGHT) do
      draw_card_frame(pdf, col_width)
      draw_photo_area(pdf, item, col_width)
      draw_card_body(pdf, item, col_width)
    end
  end

  def draw_card_frame(pdf, col_width)
    pdf.fill_color 'E2E8F0'
    pdf.transparent(0.35) { pdf.fill_rounded_rectangle [3, pdf.bounds.top - 3], col_width, CARD_HEIGHT, 10 }

    pdf.fill_color COLORS[:white]
    pdf.fill_rounded_rectangle [0, pdf.bounds.top], col_width, CARD_HEIGHT, 10
    pdf.stroke_color COLORS[:line]
    pdf.line_width = 0.6
    pdf.stroke_rounded_rectangle [0, pdf.bounds.top], col_width, CARD_HEIGHT, 10
  end

  def draw_photo_area(pdf, item, col_width)
    pdf.bounding_box([0, pdf.bounds.top], width: col_width, height: CARD_IMAGE_HEIGHT) do
      pdf.fill_color COLORS[:soft]
      pdf.fill_rounded_rectangle [0, pdf.bounds.top], col_width, CARD_IMAGE_HEIGHT, 10

      image_data = prepared_photo(item)

      if image_data
        pdf.image image_data[:path],
                  fit: [col_width - 16, CARD_IMAGE_HEIGHT - 16],
                  position: :center,
                  vposition: :center,
                  type: image_data[:type]
      else
        draw_photo_placeholder(pdf, col_width, CARD_IMAGE_HEIGHT)
      end
    rescue StandardError
      draw_photo_placeholder(pdf, col_width, CARD_IMAGE_HEIGHT)
    end
  end

  def draw_card_body(pdf, item, col_width)
    pdf.bounding_box([12, pdf.bounds.top - CARD_IMAGE_HEIGHT - 12],
                     width: col_width - 24,
                     height: CARD_HEIGHT - CARD_IMAGE_HEIGHT - 18) do
      pdf.fill_color COLORS[:teal_dark]
      pdf.text safe_text(item.name), size: 11, style: :bold, overflow: :truncate
      pdf.move_down 8

      draw_metadata_row(pdf, I18n.t('mongoid.attributes.wishlist_item.brand'), item.brand) if item.brand?
      draw_metadata_row(pdf, I18n.t('mongoid.attributes.wishlist_item.scale'), item.scale) if item.scale?
      draw_metadata_row(pdf, I18n.t('mongoid.attributes.wishlist_item.status'), item.status_label)
      draw_metadata_row(pdf, I18n.t('mongoid.attributes.wishlist_item.priority'), item.priority_label)

      return unless item.observations?

      pdf.move_down 6
      pdf.fill_color COLORS[:text_soft]
      pdf.text_box safe_text(item.observations.to_s.squish),
                   at: [0, pdf.cursor],
                   width: pdf.bounds.width,
                   height: 24,
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

  def draw_photo_placeholder(pdf, width, height)
    pdf.fill_color COLORS[:soft]
    pdf.fill_rounded_rectangle [0, pdf.bounds.top], width, height, 6
    pdf.move_down (height / 2) - 8
    pdf.fill_color COLORS[:text_soft]
    pdf.text safe_text(I18n.t('wishlist_exports.pdf.no_photo')), align: :center, size: 8.5
  end

  def prepared_photo(item)
    return if item.photo.blank? || item.photo.path.blank? || !File.exist?(item.photo.path)

    image = MiniMagick::Image.open(item.photo.path)
    real_type = image.type.downcase
    return { path: item.photo.path, type: (real_type == 'jpeg' ? :jpg : :png) } if %w[jpeg png].include?(real_type)

    temp_jpg = Tempfile.new(['wishlist_photo_convert', '.jpg'])
    temp_jpg.binmode
    @temp_files << temp_jpg
    image.format 'jpg'
    image.write temp_jpg.path

    { path: temp_jpg.path, type: :jpg }
  end

  def draw_footer(pdf)
    pdf.repeat(:all) do
      pdf.stroke_color COLORS[:line]
      pdf.line_width = 0.5
      pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.right, at: -5

      logo_path = Rails.public_path.join('logo/logo-no-bg.png')
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

  def owner_name
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

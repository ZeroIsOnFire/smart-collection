# frozen_string_literal: true

require 'prawn'

class WishlistPdfExportService
  COLORS = {
    ink: '1F2933',
    teal: '2F6F68',
    muted: '6B7280',
    soft: 'F6F1E8',
    accent: 'A56D32',
    line: 'D7C7B2',
    white: 'FFFFFF'
  }.freeze

  def initialize(user, wishlist_items, generated_at: Time.current)
    @user = user
    @wishlist_items = wishlist_items.to_a
    @generated_at = generated_at
  end

  def generate
    Prawn::Fonts::AFM.hide_m17n_warning = true

    Prawn::Document.new(page_size: 'A4', margin: [36, 32, 36, 32]) do |pdf|
      pdf.font 'Helvetica'
      draw_header(pdf)
      draw_summary(pdf)
      draw_items(pdf)
      draw_footer(pdf)
    end.render
  end

  private

  def draw_header(pdf)
    pdf.fill_color COLORS[:teal]
    pdf.fill_rounded_rectangle [0, pdf.cursor], pdf.bounds.width, 82, 8
    pdf.fill_color COLORS[:white]
    pdf.draw_text safe_text(I18n.t('wishlist_exports.pdf.eyebrow')), at: [18, pdf.cursor - 24], size: 8
    pdf.draw_text safe_text(I18n.t('wishlist_exports.pdf.title')), at: [18, pdf.cursor - 52], size: 22, style: :bold
    pdf.fill_color COLORS[:soft]
    pdf.draw_text safe_text(I18n.t('wishlist_exports.pdf.subtitle',
                                   name: @user.name.presence || I18n.t('export_pdf.user_placeholder'),
                                   date: I18n.l(@generated_at, format: :export_timestamp))),
                  at: [18, pdf.cursor - 70], size: 8
    pdf.move_down 104
  end

  def draw_summary(pdf)
    summary_rows = summary_metrics.each_slice(2).to_a
    summary_rows.each do |row|
      row.each_with_index do |metric, index|
        x = index.zero? ? 0 : (pdf.bounds.width / 2.0) + 8
        pdf.bounding_box([x, pdf.cursor], width: (pdf.bounds.width / 2.0) - 8, height: 50) do
          pdf.fill_color COLORS[:soft]
          pdf.fill_rounded_rectangle [0, pdf.bounds.top], pdf.bounds.width, 44, 6
          pdf.fill_color COLORS[:teal]
          pdf.text safe_text(metric[:value]), size: 16, style: :bold, align: :center
          pdf.fill_color COLORS[:muted]
          pdf.text safe_text(metric[:label]), size: 7.5, align: :center
        end
      end
      pdf.move_down 8
    end
    pdf.move_down 8
  end

  def draw_items(pdf)
    if @wishlist_items.empty?
      draw_empty_state(pdf)
      return
    end

    pdf.fill_color COLORS[:ink]
    pdf.text safe_text(I18n.t('wishlist_exports.pdf.items_title')), size: 13, style: :bold
    pdf.stroke_color COLORS[:line]
    pdf.stroke_horizontal_rule
    pdf.move_down 12

    @wishlist_items.each do |item|
      pdf.start_new_page if pdf.cursor < 118
      draw_item(pdf, item)
      pdf.move_down 10
    end
  end

  def draw_item(pdf, item)
    card_height = 96
    pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: card_height) do
      pdf.stroke_color COLORS[:line]
      pdf.line_width 0.6
      pdf.stroke_rounded_rectangle [0, pdf.bounds.top], pdf.bounds.width, card_height, 6
      pdf.fill_color COLORS[:white]

      draw_item_photo(pdf, item)

      pdf.bounding_box([88, pdf.bounds.top - 14], width: pdf.bounds.width - 106, height: 72) do
        pdf.fill_color COLORS[:ink]
        pdf.text safe_text(item.name), size: 12, style: :bold, overflow: :truncate
        pdf.move_down 4
        pdf.fill_color COLORS[:muted]
        pdf.text safe_text(metadata_for(item).join(' | ')), size: 8, overflow: :truncate
        if item.observations.present?
          pdf.move_down 5
          pdf.fill_color COLORS[:ink]
          pdf.text safe_text(item.observations.to_s.squish), size: 7.5, overflow: :truncate
        end
      end
    end
  end

  def draw_item_photo(pdf, item)
    pdf.bounding_box([14, pdf.bounds.top - 14], width: 62, height: 62) do
      pdf.fill_color COLORS[:soft]
      pdf.fill_rounded_rectangle [0, pdf.bounds.top], 62, 62, 5

      if item.photo? && item.photo.path && File.exist?(item.photo.path)
        pdf.image item.photo.path, fit: [62, 62], position: :center, vposition: :center
      else
        pdf.fill_color COLORS[:muted]
        pdf.text_box safe_text(I18n.t('wishlist_exports.pdf.no_photo')),
                     at: [0, 36],
                     width: 62,
                     align: :center,
                     size: 7
      end
    end
  rescue StandardError
    pdf.fill_color COLORS[:muted]
    pdf.text_box safe_text(I18n.t('wishlist_exports.pdf.no_photo')),
                 at: [0, 36],
                 width: 62,
                 align: :center,
                 size: 7
  end

  def draw_empty_state(pdf)
    pdf.move_down 80
    pdf.fill_color COLORS[:muted]
    pdf.text safe_text(I18n.t('wishlist_exports.pdf.empty')), align: :center, size: 11
  end

  def draw_footer(pdf)
    pdf.repeat(:all) do
      pdf.stroke_color COLORS[:line]
      pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.right, at: -8
      pdf.fill_color COLORS[:muted]
      pdf.draw_text safe_text(I18n.t('wishlist_exports.pdf.generated_by')), at: [pdf.bounds.left, -25], size: 8
    end
  end

  def summary_metrics
    total = @wishlist_items.size
    status_counts = @wishlist_items.group_by(&:status).transform_values(&:count)
    priority_counts = @wishlist_items.group_by(&:priority).transform_values(&:count)

    [
      { label: I18n.t('wishlist_exports.pdf.summary.total'), value: total.to_s },
      { label: I18n.t('wishlist_items.statuses.wanted'), value: status_counts.fetch('wanted', 0).to_s },
      { label: I18n.t('wishlist_items.statuses.purchased'), value: status_counts.fetch('purchased', 0).to_s },
      { label: I18n.t('wishlist_items.priorities.dream'), value: priority_counts.fetch('dream', 0).to_s }
    ]
  end

  def metadata_for(item)
    [
      item.brand,
      item.scale,
      item.status_label,
      item.priority_label
    ].compact_blank
  end

  def safe_text(value)
    value.to_s.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?')
  end
end

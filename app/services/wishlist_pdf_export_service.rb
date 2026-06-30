# frozen_string_literal: true

require 'prawn'

class WishlistPdfExportService
  COLORS = {
    ink: '1F2933',
    teal: '2F6F68',
    muted: '6B7280',
    soft: 'F6F1E8',
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
    pdf.text safe_text(I18n.t('wishlist_exports.pdf.title')), size: 18, style: :bold
    pdf.move_down 4
    pdf.fill_color COLORS[:muted]
    pdf.text safe_text(I18n.t('wishlist_exports.pdf.subtitle',
                              name: @user.name.presence || I18n.t('export_pdf.user_placeholder'),
                              date: I18n.l(@generated_at, format: :export_timestamp))),
             size: 9
    pdf.move_down 18
  end

  def draw_summary(pdf)
    summary_rows = summary_metrics.each_slice(2).to_a
    summary_rows.each do |row|
      row.each_with_index do |metric, index|
        x = index.zero? ? 0 : (pdf.bounds.width / 2.0) + 8
        pdf.bounding_box([x, pdf.cursor], width: (pdf.bounds.width / 2.0) - 8, height: 48) do
          pdf.fill_color COLORS[:soft]
          pdf.fill_rounded_rectangle [0, pdf.bounds.top], pdf.bounds.width, 42, 6
          pdf.fill_color COLORS[:teal]
          pdf.text safe_text(metric[:value]), size: 15, style: :bold, align: :center
          pdf.fill_color COLORS[:muted]
          pdf.text safe_text(metric[:label]), size: 7, align: :center
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

    @wishlist_items.each do |item|
      pdf.start_new_page if pdf.cursor < 105
      draw_item(pdf, item)
      pdf.move_down 10
    end
  end

  def draw_item(pdf, item)
    card_height = 86
    pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: card_height) do
      pdf.stroke_color COLORS[:line]
      pdf.line_width 0.6
      pdf.stroke_rounded_rectangle [0, pdf.bounds.top], pdf.bounds.width, card_height, 6

      draw_item_photo(pdf, item)

      pdf.bounding_box([78, pdf.bounds.top - 12], width: pdf.bounds.width - 94, height: 64) do
        pdf.fill_color COLORS[:ink]
        pdf.text safe_text(item.name), size: 11, style: :bold, overflow: :truncate
        pdf.move_down 4
        pdf.fill_color COLORS[:muted]
        pdf.text safe_text(metadata_for(item).join(' | ')), size: 8, overflow: :truncate
        pdf.move_down 4
        pdf.text safe_text(item.observations.to_s.squish), size: 7.5, overflow: :truncate if item.observations.present?
      end
    end
  end

  def draw_item_photo(pdf, item)
    pdf.bounding_box([12, pdf.bounds.top - 12], width: 54, height: 54) do
      pdf.fill_color COLORS[:soft]
      pdf.fill_rounded_rectangle [0, pdf.bounds.top], 54, 54, 5

      if item.photo? && item.photo.path && File.exist?(item.photo.path)
        pdf.image item.photo.path, fit: [54, 54], position: :center, vposition: :center
      else
        pdf.fill_color COLORS[:muted]
        pdf.text_box safe_text(I18n.t('wishlist_exports.pdf.no_photo')),
                     at: [0, 32],
                     width: 54,
                     align: :center,
                     size: 7
      end
    end
  rescue StandardError
    pdf.fill_color COLORS[:muted]
    pdf.text_box safe_text(I18n.t('wishlist_exports.pdf.no_photo')),
                 at: [0, 32],
                 width: 54,
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
      item.priority_label,
      formatted_price(item)
    ].compact_blank
  end

  def formatted_price(item)
    return nil if item.target_price_cents.blank?

    ActionController::Base.helpers.number_to_currency(item.target_price)
  end

  def safe_text(value)
    value.to_s.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?')
  end
end

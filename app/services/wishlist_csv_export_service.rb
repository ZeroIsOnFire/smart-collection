# frozen_string_literal: true

require 'csv'

class WishlistCsvExportService
  HEADERS = %i[
    name
    brand
    scale
    observations
    priority
    status
    target_price
    reference_url
    created_at
    updated_at
  ].freeze

  def initialize(wishlist_items)
    @wishlist_items = wishlist_items
  end

  def generate
    CSV.generate(headers: true) do |csv|
      csv << HEADERS.map { |header| I18n.t("wishlist_exports.csv.headers.#{header}") }

      @wishlist_items.each do |item|
        csv << [
          item.name,
          item.brand,
          item.scale,
          item.observations.to_s.squish,
          item.priority_label,
          item.status_label,
          formatted_price(item),
          item.reference_url,
          I18n.l(item.created_at, format: :export_timestamp),
          I18n.l(item.updated_at, format: :export_timestamp)
        ]
      end
    end
  end

  private

  def formatted_price(item)
    return nil if item.target_price_cents.blank?

    format('%.2f', item.target_price)
  end
end

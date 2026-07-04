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
          item.reference_url,
          I18n.l(item.created_at, format: :export_timestamp),
          I18n.l(item.updated_at, format: :export_timestamp)
        ]
      end
    end
  end
end

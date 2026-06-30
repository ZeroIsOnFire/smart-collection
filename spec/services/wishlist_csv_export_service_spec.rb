# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WishlistCsvExportService do
  describe '#generate' do
    it 'exports wishlist item fields with translated labels' do
      item = create(
        :wishlist_item,
        name: 'Blue Porsche',
        priority: 'high',
        status: 'reserved',
        target_price_cents: 12_990
      )

      csv = described_class.new([item]).generate

      expect(csv).to include(I18n.t('wishlist_exports.csv.headers.name'))
      expect(csv).to include('Blue Porsche')
      expect(csv).to include(I18n.t('wishlist_items.priorities.high'))
      expect(csv).to include(I18n.t('wishlist_items.statuses.reserved'))
      expect(csv).not_to include('129.90')
      expect(csv).not_to include('Target price')
    end
  end
end

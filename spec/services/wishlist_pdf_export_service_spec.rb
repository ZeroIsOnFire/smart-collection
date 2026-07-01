# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WishlistPdfExportService do
  let(:user) { create(:user, name: 'Test User') }

  describe '#generate' do
    it 'generates PDF content' do
      create(:wishlist_item, user: user)

      pdf_content = described_class.new(user, user.wishlist_items).generate

      expect(pdf_content).to be_a(String)
      expect(pdf_content).to start_with('%PDF')
      expect(pdf_content.scan(%r{/Type\s*/Page\b}).count).to eq(1)
    end

    it 'handles an empty wishlist' do
      pdf_content = described_class.new(user, []).generate

      expect(pdf_content).to start_with('%PDF')
    end
  end
end

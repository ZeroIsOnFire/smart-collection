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

    it 'uses the wishlist item count for singular and plural header text' do
      wishlist_item = create(:wishlist_item, user: user)
      allow(I18n).to receive(:t).and_call_original

      described_class.new(user, [wishlist_item]).generate

      expect(I18n).to have_received(:t).with('wishlist_exports.pdf.meta_info', count: 1, date: kind_of(String))
    end

    it 'translates the PDF count with the expected pt-BR pluralization' do
      I18n.with_locale(:'pt-BR') do
        expect(I18n.t('wishlist_exports.pdf.meta_info', count: 1, date: '01/07/2026 10:00'))
          .to eq('1 carro desejado | Gerado em 01/07/2026 10:00')
        expect(I18n.t('wishlist_exports.pdf.meta_info', count: 0, date: '01/07/2026 10:00'))
          .to eq('0 carros desejados | Gerado em 01/07/2026 10:00')
      end
    end

    it 'handles an empty wishlist' do
      pdf_content = described_class.new(user, []).generate

      expect(pdf_content).to start_with('%PDF')
    end
  end
end

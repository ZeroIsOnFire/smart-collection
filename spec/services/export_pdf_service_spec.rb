# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportPdfService do
  let(:user) { create(:user, name: 'Test User') }
  let(:cars) { create_list(:car, 2, user: user) }
  let(:service) { described_class.new(user, cars) }

  describe '#generate' do
    it 'generates a PDF content' do
      pdf_content = service.generate
      expect(pdf_content).to be_a(String)
      expect(pdf_content).to start_with('%PDF')
    end

    it 'handles users with special characters in name' do
      user.update(name: 'João Ações')
      pdf_content = service.generate
      expect(pdf_content).to be_a(String)
    end

    it 'uses the provided generation date in the report metadata' do
      generated_at = Time.zone.local(2026, 1, 15, 10, 30)
      allow(I18n).to receive(:l).and_call_original

      described_class.new(user, cars, generated_at: generated_at).generate

      expect(I18n).to have_received(:l).with(generated_at, format: :export_timestamp)
    end

    it 'marks photos displayed with the AI-enhanced variant' do
      car = create(:car, user: user, photo_variant: 'ai')
      car.photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.save!
      service = described_class.new(user, [car])

      expect(service).to receive(:draw_ai_photo_badge).once.and_call_original

      service.generate
    end

    it 'does not mark photos displayed with the original variant' do
      car = create(:car, user: user, photo_variant: 'original')
      car.photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.save!
      service = described_class.new(user, [car])

      expect(service).not_to receive(:draw_ai_photo_badge)

      service.generate
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Car, type: :model do
  let(:user) { create(:user) }
  let(:car) { build(:car, user: user) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(car).to be_valid
    end

    it 'is not valid without a name' do
      car.name = nil
      expect(car).not_to be_valid
      expect(car.errors[:name]).to include('não pode ficar em branco')
    end

    it 'is valid without a brand' do
      car.brand = nil
      expect(car).to be_valid
    end

    it 'is not valid with a non-numeric year' do
      car.year = 'abcd'

      expect(car).not_to be_valid
      expect(car.errors[:year]).to include(I18n.t('errors.messages.not_a_number'))
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      expect(car.user).to eq(user)
    end
  end

  describe '#photo_processing_crop?' do
    it 'returns true only when the car is processing and has complete crop data' do
      car.photo_processing_status = 'pending'
      car.photo_processing_crop_x = 0.1
      car.photo_processing_crop_y = 0.2
      car.photo_processing_crop_w = 0.3
      car.photo_processing_crop_h = 0.4

      expect(car.photo_processing_crop?).to be true
    end

    it 'returns false after processing finishes' do
      car.photo_processing_status = 'completed'
      car.photo_processing_crop_x = 0.1
      car.photo_processing_crop_y = 0.2
      car.photo_processing_crop_w = 0.3
      car.photo_processing_crop_h = 0.4

      expect(car.photo_processing_crop?).to be false
    end
  end

  describe '#photo_upscaled_by_ai?' do
    it 'is true for legacy AI photos without stored variants' do
      car.photo_upscale_strategy = 'ai'

      expect(car.photo_upscaled_by_ai?).to be true
    end

    it 'is true only when the displayed variant is the enhanced AI photo' do
      car.original_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'original'

      expect(car.photo_upscaled_by_ai?).to be false

      car.photo_variant = 'ai'

      expect(car.photo_upscaled_by_ai?).to be true
    end
  end

  describe 'share image cache' do
    it 'clears the cached share image when updated' do
      persisted_car = create(:car, user: user)
      allow(ShareImageCacheService).to receive(:clear)

      persisted_car.update!(name: 'Updated car')

      expect(ShareImageCacheService).to have_received(:clear).with(record: persisted_car, kind: :car)
    end

    it 'clears the cached share image when destroyed' do
      persisted_car = create(:car, user: user)
      allow(ShareImageCacheService).to receive(:clear)

      persisted_car.destroy!

      expect(ShareImageCacheService).to have_received(:clear).with(record: persisted_car, kind: :car)
    end
  end
end

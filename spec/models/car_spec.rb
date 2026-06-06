# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Car, type: :model do
  let(:user) { create(:user) }
  let(:car) { build(:car, user: user) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(car).to be_valid
    end

    it 'is valid without a manufacturer' do
      car.manufacturer = nil
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
end

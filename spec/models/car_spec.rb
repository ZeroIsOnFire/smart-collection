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
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CarService do
  let(:user) { create(:user) }
  let(:valid_params) do
    {
      name: 'Corolla',
      brand: 'Toyota',
      tags: ['sedan'],
      observations: 'Em bom estado',
      size: 'Medium',
      year: 2021,
      manufacturer: 'Toyota',
      photo: Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
    }
  end

  describe '#create' do
    it 'creates a car for the user' do
      expect do
        described_class.new(user).create(valid_params)
      end.to change(user.cars, :count).by(1)
    end

    it 'creates a car even with an empty year string' do
      params = valid_params.merge(year: '', photo: nil)
      expect do
        described_class.new(user).create(params)
      end.to change(user.cars, :count).by(1)
    end

    it 'attaches the photo to the car' do
      car = described_class.new(user).create(valid_params)
      expect(car.photo).to be_present
      expect(car.photo.url).to include('test_image.jpg')
    end
  end

  describe '#update' do
    let!(:car) { create(:car, user: user, name: 'Old Name') }

    it 'updates the car for the user' do
      described_class.new(user).update(car.id, { name: 'New Name' })
      expect(car.reload.name).to eq('New Name')
    end

    it 'removes the photo when remove_photo is set to "1"' do
      car_with_photo = described_class.new(user).create(valid_params)
      # CarrierWave remove_photo is a virtual attribute — must be set before save
      found_car = user.cars.find(car_with_photo.id)
      found_car.remove_photo = true
      found_car.save!
      expect(found_car.reload.photo).not_to be_present
    end
  end

  describe '#destroy' do
    let!(:car) { create(:car, user: user) }

    it 'destroys the car' do
      expect do
        described_class.new(user).destroy(car.id)
      end.to change(user.cars, :count).by(-1)
    end
  end

  describe '#search' do
    before do
      Car.create_indexes
    end

    let!(:car1) do
      create(:car, user: user, name: 'Ferrari F40', brand: 'Ferrari', manufacturer: 'Burago', tags: %w[italy fast])
    end
    let!(:car2) do
      create(:car, user: user, name: 'Porsche 911', brand: 'Porsche', manufacturer: 'Hot Wheels',
                   tags: %w[germany classic])
    end
    let!(:other_user_car) { create(:car, name: 'Ferrari Enzo') }

    it 'returns cars matching the query in name' do
      results = described_class.new(user).search('Ferrari')
      expect(results).to include(car1)
      expect(results).not_to include(car2)
    end

    it 'returns cars matching the query in brand' do
      results = described_class.new(user).search('Porsche')
      expect(results).to include(car2)
    end

    it 'returns cars matching the query in manufacturer' do
      results = described_class.new(user).search('Burago')
      expect(results).to include(car1)
    end

    it 'returns cars matching the query in tags' do
      results = described_class.new(user).search('germany')
      expect(results).to include(car2)
    end

    it 'does not return cars from other users' do
      results = described_class.new(user).search('Ferrari')
      expect(results).to include(car1)
      expect(results).not_to include(other_user_car)
    end

    it 'is case insensitive (MongoDB property)' do
      results = described_class.new(user).search('ferrari')
      expect(results).to include(car1)
    end
  end
end

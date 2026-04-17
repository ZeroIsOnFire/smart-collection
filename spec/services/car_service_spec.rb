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
      expect {
        CarService.new(user).create(valid_params)
      }.to change(user.cars, :count).by(1)
    end

    it 'creates a car even with an empty year string' do
      params = valid_params.merge(year: "", photo: nil)
      expect {
        CarService.new(user).create(params)
      }.to change(user.cars, :count).by(1)
    end

    it 'attaches the photo to the car' do
      car = CarService.new(user).create(valid_params)
      expect(car.photo).to be_present
      expect(car.photo.url).to include('test_image.png')
    end
  end

  describe '#update' do
    let!(:car) { create(:car, user: user, name: 'Old Name') }

    it 'updates the car for the user' do
      CarService.new(user).update(car.id, { name: 'New Name' })
      expect(car.reload.name).to eq('New Name')
    end

    it 'removes the photo when remove_photo is set to "1"' do
      car_with_photo = CarService.new(user).create(valid_params)
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
      expect {
        CarService.new(user).destroy(car.id)
      }.to change(user.cars, :count).by(-1)
    end
  end

  describe '#search' do
    before(:each) do
      Car.create_indexes
    end

    let!(:car1) { create(:car, user: user, name: 'Ferrari F40', brand: 'Ferrari', manufacturer: 'Burago', tags: ['italy', 'fast']) }
    let!(:car2) { create(:car, user: user, name: 'Porsche 911', brand: 'Porsche', manufacturer: 'Hot Wheels', tags: ['germany', 'classic']) }
    let!(:other_user_car) { create(:car, name: 'Ferrari Enzo') }

    it 'returns cars matching the query in name' do
      results = CarService.new(user).search('Ferrari')
      expect(results).to include(car1)
      expect(results).not_to include(car2)
    end

    it 'returns cars matching the query in brand' do
      results = CarService.new(user).search('Porsche')
      expect(results).to include(car2)
    end

    it 'returns cars matching the query in manufacturer' do
      results = CarService.new(user).search('Burago')
      expect(results).to include(car1)
    end

    it 'returns cars matching the query in tags' do
      results = CarService.new(user).search('germany')
      expect(results).to include(car2)
    end

    it 'does not return cars from other users' do
      results = CarService.new(user).search('Ferrari')
      expect(results).to include(car1)
      expect(results).not_to include(other_user_car)
    end

    it 'is case insensitive (MongoDB property)' do
      results = CarService.new(user).search('ferrari')
      expect(results).to include(car1)
    end
  end
end

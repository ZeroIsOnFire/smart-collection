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

  def build_temp_image(width:, height:, filename: 'upscaled.jpg')
    tempfile = Tempfile.new(['upscaled', '.jpg'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(Rails.root.join('spec/fixtures/files/test_image.png'))
    image.resize "#{width}x#{height}!"
    image.write(tempfile.path)
    tempfile.define_singleton_method(:original_filename) { filename }
    tempfile.define_singleton_method(:content_type) { 'image/jpeg' }
    tempfile
  end

  describe '#create' do
    it 'creates a car for the user' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)

      expect do
        described_class.new(user).create(valid_params)
      end.to change { user.reload.cars.count }.by(1)
    end

    it 'passes the photo through the upscaler before persistence' do
      expect(ImageUpscalerService).to receive(:upscale_if_needed).at_least(:once).and_return(nil)

      described_class.new(user).create(valid_params)
    end

    it 'persists the upscaled photo when the source image is small' do
      upscaled_file = build_temp_image(width: 420, height: 280)
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(upscaled_file)

      car = described_class.new(user).create(valid_params)

      saved_image = MiniMagick::Image.open(car.photo.path)
      expect(saved_image.width).to eq(420)
      expect(saved_image.height).to eq(280)
    ensure
      upscaled_file.close if upscaled_file
      upscaled_file.unlink if upscaled_file
    end

    it 'creates a car even with an empty year string' do
      params = valid_params.merge(year: '', photo: nil)
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)

      expect do
        described_class.new(user).create(params)
      end.to change { user.reload.cars.count }.by(1)
    end

    it 'attaches the photo to the car' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)
      car = described_class.new(user).create(valid_params)

      expect(car.photo).to be_present
      expect(car.photo.url).to include('test_image.jpg')
    end
  end

  describe 'upscale errors' do
    it 'returns a car with an error when the upscaler fails during create' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed)
        .and_raise(ImageUpscalerService::UpscaleError, 'upscaler failed')

      car = described_class.new(user).create(valid_params)

      expect(car.persisted?).to be_falsey
      expect(car.errors[:photo]).to include('upscaler failed')
    end
  end

  describe '#update' do
    let!(:car) { create(:car, user: user, name: 'Old Name') }

    it 'updates the car for the user' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)

      described_class.new(user).update(car.id, { name: 'New Name' })

      expect(car.reload.name).to eq('New Name')
    end

    it 'removes the photo when remove_photo is set to "1"' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)
      car_with_photo = described_class.new(user).create(valid_params)

      found_car = user.cars.find(car_with_photo.id)
      found_car.remove_photo = true
      found_car.save!

      expect(found_car.reload.photo).not_to be_present
    end

    it 'returns a car with an error when the upscaler fails during update' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed)
        .and_raise(ImageUpscalerService::UpscaleError, 'upscaler failed')

      updated_car = described_class.new(user).update(car.id, { photo: valid_params[:photo] })

      expect(updated_car.errors[:photo]).to include('upscaler failed')
    end
  end

  describe '#destroy' do
    let!(:car) { create(:car, user: user) }

    it 'destroys the car' do
      expect do
        described_class.new(user).destroy(car.id)
      end.to change { user.reload.cars.count }.by(-1)
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

  describe '#all' do
    before do
      create_list(:car, 21, user: user)
    end

    it 'returns a paginatable collection' do
      results = described_class.new(user).all(page: 2, per_page: 20)

      expect(results.current_page).to eq(2)
      expect(results.total_pages).to eq(2)
      expect(results.next_page).to be_nil
      expect(results.to_a.size).to eq(1)
    end
  end
end

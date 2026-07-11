# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CarService do
  let(:user) { create(:user) }
  let(:valid_params) do
    {
      name: 'Toyota Corolla',
      brand: 'Toyota',
      tags: ['sedan'],
      observations: 'Em bom estado',
      size: 'Medium',
      year: 2021,
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

  def build_uploaded_image(width:, height:, filename: 'small.jpg')
    tempfile = build_temp_image(width:, height:, filename:)
    Rack::Test::UploadedFile.new(tempfile.path, 'image/jpeg', original_filename: filename)
  end

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '.ensure_text_search_index!' do
    before do
      described_class.remove_instance_variable(:@text_search_index_checked) if described_class.instance_variable_defined?(:@text_search_index_checked)
    end

    it 'refreshes indexes when the text search index is missing' do
      allow(described_class).to receive(:text_search_index_current?).and_return(false)

      expect(described_class).to receive(:refresh_text_search_index!)

      described_class.ensure_text_search_index!
    end

    it 'does not refresh indexes when the text search index is current' do
      allow(described_class).to receive(:text_search_index_current?).and_return(true)

      expect(described_class).not_to receive(:refresh_text_search_index!)

      described_class.ensure_text_search_index!
    end
  end

  describe '#create' do
    it 'creates a car for the user' do
      expect do
        described_class.new(user).create(valid_params)
      end.to change { user.reload.cars.count }.by(1)
    end

    it 'enqueues photo processing instead of running heavy image services in the request' do
      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
      expect(ImageCropperService).not_to receive(:crop)
      expect(YoloDetectionService).not_to receive(:classify_color)

      expect do
        car = described_class.new(user).create(valid_params)
        expect(car.photo_processing_status).to eq('pending')
      end.to enqueue_job(CarImageProcessingJob)
    end

    it 'passes crop values to the background job' do
      params = valid_params.merge(crop_x: '0.1', crop_y: '0.2', crop_w: '0.3', crop_h: '0.4')

      expect do
        described_class.new(user).create(params)
      end.to enqueue_job(CarImageProcessingJob).with(
        user.id.to_s,
        kind_of(String),
        crop_x: '0.1',
        crop_y: '0.2',
        crop_w: '0.3',
        crop_h: '0.4'
      )
    end

    it 'selects the AI photo after processing when the per-record upscaler is enabled' do
      params = valid_params.merge(skip_upscaler: '0')
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      expect do
        described_class.new(user).create(params)
      end.to enqueue_job(CarImageProcessingJob).with(
        user.id.to_s,
        kind_of(String),
        force_ai_upscale: true
      )
    end

    it 'keeps crop values for the processing thumbnail' do
      params = valid_params.merge(crop_x: '0.1', crop_y: '0.2', crop_w: '0.3', crop_h: '0.4')

      car = described_class.new(user).create(params)

      expect(car.photo_processing_crop_x).to eq(0.1)
      expect(car.photo_processing_crop_y).to eq(0.2)
      expect(car.photo_processing_crop_w).to eq(0.3)
      expect(car.photo_processing_crop_h).to eq(0.4)
      expect(car.photo_crop_x).to eq(0.1)
      expect(car.photo_crop_y).to eq(0.2)
      expect(car.photo_crop_w).to eq(0.3)
      expect(car.photo_crop_h).to eq(0.4)
    end

    it 'does not enqueue photo processing when no photo or crop is provided' do
      params = valid_params.merge(photo: nil)

      expect do
        car = described_class.new(user).create(params)

        expect(car).not_to be_persisted
        expect(car.errors[:photo]).to be_present
      end.not_to enqueue_job(CarImageProcessingJob)
    end

    it 'collects regular validation errors together with the missing photo error' do
      params = valid_params.merge(name: '', photo: nil)

      car = described_class.new(user).create(params)

      expect(car).not_to be_persisted
      expect(car.errors[:name]).to be_present
      expect(car.errors[:photo]).to be_present
    end

    it 'creates a car even with an empty year string' do
      params = valid_params.merge(year: '')

      expect do
        described_class.new(user).create(params)
      end.to change { user.reload.cars.count }.by(1)
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

      found_car = user.cars.find(car_with_photo.id)
      found_car.remove_photo = true
      found_car.save!

      expect(found_car.reload.photo).not_to be_present
    end

    it 'enqueues photo processing when the photo changes' do
      expect do
        updated_car = described_class.new(user).update(car.id, { photo: valid_params[:photo] })
        expect(updated_car.photo_processing_status).to eq('pending')
      end.to enqueue_job(CarImageProcessingJob)
    end

    it 'clears stored AI variants when the photo changes' do
      car.original_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.photo_crop_x = 0.1
      car.photo_crop_y = 0.2
      car.photo_crop_w = 0.3
      car.photo_crop_h = 0.4
      car.save!

      updated_car = described_class.new(user).update(car.id, { photo: valid_params[:photo] })

      expect(updated_car.original_photo).not_to be_present
      expect(updated_car.enhanced_photo).not_to be_present
      expect(updated_car.photo_variant).to be_nil
      expect(updated_car.photo_upscale_strategy).to be_nil
      expect(updated_car.photo_crop_x).to be_nil
      expect(updated_car.photo_crop_y).to be_nil
      expect(updated_car.photo_crop_w).to be_nil
      expect(updated_car.photo_crop_h).to be_nil
    end

    it 'switches an existing car back to the original photo when the upscaler toggle is checked' do
      car.original_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.save!

      updated_car = described_class.new(user).update(car.id, { skip_upscaler: '1' })

      expect(updated_car.photo_variant).to eq('original')
      expect(updated_car.photo_upscale_strategy).to be_nil
      expect(updated_car).not_to be_photo_upscaled_by_ai
    end

    it 'does not crop again when selecting the original variant with unchanged crop fields' do
      car.original_photo = build_uploaded_image(width: 240, height: 240, filename: 'cropped_original.jpg')
      car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.photo_crop_x = 0.1
      car.photo_crop_y = 0.2
      car.photo_crop_w = 0.3
      car.photo_crop_h = 0.4
      car.save!

      expect do
        updated_car = described_class.new(user).update(
          car.id,
          {
            skip_upscaler: '1',
            crop_x: '0.1',
            crop_y: '0.2',
            crop_w: '0.3',
            crop_h: '0.4'
          }
        )

        expect(updated_car.photo_processing_status).to be_nil
        expect(updated_car.photo_variant).to eq('original')
        expect(updated_car.photo_upscale_strategy).to be_nil
      end.not_to enqueue_job(CarImageProcessingJob)
    end

    it 'uses the existing enhanced photo when the upscaler toggle is unchecked' do
      car.original_photo = build_uploaded_image(width: 240, height: 240, filename: 'small_original.jpg')
      car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo = build_uploaded_image(width: 240, height: 240, filename: 'small_current.jpg')
      car.photo_variant = 'original'
      car.skip_upscaler = true
      car.save!

      expect do
        updated_car = described_class.new(user).update(car.id, { skip_upscaler: '0' })
        expect(updated_car.photo_variant).to eq('ai')
        expect(updated_car.photo_upscale_strategy).to eq('ai')
      end.not_to enqueue_job(CarImageProcessingJob)
    end

    it 'keeps the original selected when account AI upscaling is disabled' do
      user.update!(ai_upscaling_enabled: false)
      car.original_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.photo_variant = 'original'
      car.skip_upscaler = true
      car.save!

      updated_car = described_class.new(user).update(car.id, { skip_upscaler: '0' })

      expect(updated_car.photo_variant).to eq('original')
      expect(updated_car.photo_upscale_strategy).to be_nil
      expect(updated_car.skip_upscaler).to be true
    end

    it 'enqueues AI processing when enabling the upscaler for a car without an enhanced photo' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
      car.photo = build_uploaded_image(width: 240, height: 240)
      car.original_photo = build_uploaded_image(width: 240, height: 240)
      car.skip_upscaler = true
      car.save!

      expect do
        updated_car = described_class.new(user).update(car.id, { skip_upscaler: '0' })
        expect(updated_car.photo_processing_status).to eq('pending')
      end.to enqueue_job(CarImageProcessingJob).with(
        user.id.to_s,
        car.id.to_s,
        force_ai_upscale: true,
        bulk_ai_upscale: false
      )
    end

    it 'does not enqueue AI processing when the original already meets the required size' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
      car.photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.original_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.skip_upscaler = true
      car.save!

      expect do
        updated_car = described_class.new(user).update(car.id, { skip_upscaler: '0' })
        expect(updated_car.photo_processing_status).to be_nil
        expect(updated_car.photo_variant).to eq('original')
      end.not_to enqueue_job(CarImageProcessingJob)
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
      create(:car, user: user, name: 'Burago Ferrari F40', brand: 'Ferrari', tags: %w[italy fast])
    end
    let!(:car2) do
      create(:car, user: user, name: 'Hot Wheels Porsche 911', brand: 'Porsche',
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

    it 'returns cars matching the vehicle manufacturer included in the name' do
      results = described_class.new(user).search('Burago')
      expect(results).to include(car1)
    end

    it 'returns cars matching the query in tags' do
      results = described_class.new(user).search('germany')
      expect(results).to include(car2)
    end

    it 'returns cars matching the query in scale' do
      car1.update!(size: '1:64')

      results = described_class.new(user).search('1:64')

      expect(results).to include(car1)
      expect(results).not_to include(car2)
    end

    it 'does not search cars by color' do
      car2.update!(color: 'blue')

      results = described_class.new(user).search('blue')

      expect(results).to be_empty
    end

    it 'returns cars matching the query in year' do
      car1.update!(year: 1988)

      results = described_class.new(user).search('1988')

      expect(results).to include(car1)
      expect(results).not_to include(car2)
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

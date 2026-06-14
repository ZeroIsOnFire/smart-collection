# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CarImageProcessingJob do
  let(:user) { create(:user) }
  let(:car) { create(:car, user: user, color: nil) }

  def attach_photo!(record)
    record.photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
    record.photo_processing_status = 'pending'
    record.save!
    record
  end

  def build_temp_image(width:, height:, filename: 'processed.jpg', upscale_strategy: nil)
    tempfile = Tempfile.new(['processed', '.jpg'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(Rails.root.join('spec/fixtures/files/test_image.png'))
    image.resize "#{width}x#{height}!"
    image.write(tempfile.path)
    tempfile.define_singleton_method(:original_filename) { filename }
    tempfile.define_singleton_method(:content_type) { 'image/jpeg' }
    tempfile.define_singleton_method(:upscale_strategy) { upscale_strategy } if upscale_strategy
    tempfile
  end

  describe '#perform' do
    it 'upscales and classifies the photo in the background' do
      attach_photo!(car)
      upscaled_file = build_temp_image(width: 420, height: 280)

      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(anything, minimum_side: ImageUpscalerService.default_minimum_side, use_ai: true, local_fallback: false)
        .and_return(upscaled_file)
      expect(YoloDetectionService).to receive(:classify_color).and_return('Azul')

      described_class.new.perform(user.id.to_s, car.id.to_s)

      processed_car = Car.find(car.id)
      saved_image = MiniMagick::Image.open(processed_car.photo.path)
      expect(saved_image.width).to eq(420)
      expect(saved_image.height).to eq(280)
      expect(processed_car.color).to eq('Azul')
      expect(processed_car.photo_processing_status).to eq('completed')
      expect(processed_car.photo_processing_error).to be_nil
      expect(processed_car.photo_processing_crop?).to be false
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        "cars_#{user.id}",
        target: "car_#{car.id}",
        partial: 'cars/car',
        locals: { car: processed_car }
      ).at_least(:once)
    end

    it 'tracks upscaled photos in the historical counters' do
      attach_photo!(car)
      upscaled_file = build_temp_image(width: 420, height: 280, upscale_strategy: :ai)

      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(upscaled_file)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      expect do
        described_class.new.perform(user.id.to_s, car.id.to_s)
      end.to change { UsageMetric.values_for(['photos_upscaled_ai']).fetch('photos_upscaled_ai') }.from(0).to(1)
      expect(Car.find(car.id).photo_upscale_strategy).to eq('ai')
    end

    it 'uses crop parameters when they are present' do
      attach_photo!(car)
      cropped_file = build_temp_image(width: 360, height: 360)
      crop_params = { crop_x: '0.1', crop_y: '0.2', crop_w: '0.3', crop_h: '0.4' }

      expect(ImageCropperService).to receive(:crop)
        .with(
          anything,
          [
            { 'x' => 0.1, 'y' => 0.2 },
            { 'x' => 0.4, 'y' => 0.2 },
            { 'x' => 0.4, 'y' => 0.6 },
            { 'x' => 0.1, 'y' => 0.6 }
          ],
          padding: 0,
          minimum_side: ImageUpscalerService.default_minimum_side,
          upscale: { use_ai: true, local_fallback: false }
        )
        .and_return(cropped_file)
      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      described_class.new.perform(user.id.to_s, car.id.to_s, crop_params)

      expect(Car.find(car.id).photo_processing_status).to eq('completed')
    end

    it 'honors the user AI upscaling preference' do
      user.update!(ai_upscaling_enabled: false)
      attach_photo!(car)

      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(anything, minimum_side: ImageUpscalerService.default_minimum_side, use_ai: false, local_fallback: false)
        .and_return(nil)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      described_class.new.perform(user.id.to_s, car.id.to_s)

      expect(Car.find(car.id).photo_processing_status).to eq('completed')
    end

    it 'preserves an inherited AI strategy when no extra upscale is needed' do
      attach_photo!(car)
      car.update!(photo_upscale_strategy: 'ai')

      expect(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      described_class.new.perform(user.id.to_s, car.id.to_s, photo_upscale_strategy: 'ai')

      processed_car = Car.find(car.id)
      expect(processed_car.photo_processing_status).to eq('completed')
      expect(processed_car.photo_upscale_strategy).to eq('ai')
    end

    it 'keeps AI strategy when inherited from autodetection and the car receives local upscale' do
      attach_photo!(car)
      car.update!(photo_upscale_strategy: 'ai')
      upscaled_file = build_temp_image(width: 420, height: 280, upscale_strategy: :local)

      expect(ImageUpscalerService).to receive(:upscale_if_needed).and_return(upscaled_file)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      described_class.new.perform(user.id.to_s, car.id.to_s, photo_upscale_strategy: 'ai')

      expect(Car.find(car.id).photo_upscale_strategy).to eq('ai')
    end

    it 'skips the upscaler for a car with the per-record flag enabled' do
      car.update!(skip_upscaler: true)
      attach_photo!(car)

      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      described_class.new.perform(user.id.to_s, car.id.to_s)

      processed_car = Car.find(car.id)
      expect(processed_car.photo_processing_status).to eq('completed')
      expect(processed_car.photo_upscale_strategy).to be_nil
    end

    it 'preserves an inherited AI strategy when the car skips extra upscaling' do
      car.update!(skip_upscaler: true, photo_upscale_strategy: 'ai')
      attach_photo!(car)

      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      described_class.new.perform(user.id.to_s, car.id.to_s, photo_upscale_strategy: 'ai')

      expect(Car.find(car.id).photo_upscale_strategy).to eq('ai')
    end

    it 'syncs the linked detected item preview after processing the created car photo' do
      autodetection = create(:autodetection, user: user)
      detected_item = create(:detected_item, autodetection: autodetection, car_id: car.id, status: 'saved')
      attach_photo!(car)
      upscaled_file = build_temp_image(width: 420, height: 280, upscale_strategy: :ai)

      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      expect(ImageUpscalerService).to receive(:upscale_if_needed).and_return(upscaled_file)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      described_class.new.perform(user.id.to_s, car.id.to_s)

      synced_item = DetectedItem.find(detected_item.id)
      synced_image = MiniMagick::Image.open(synced_item.cropped_photo.path)

      expect(synced_image.width).to eq(420)
      expect(synced_item.cropped_photo_upscale_strategy).to eq('ai')
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        "autodetection_#{autodetection.id}_items",
        target: "detected_item_#{detected_item.id}",
        partial: 'detected_items/detected_item',
        locals: { detected_item: synced_item }
      )
    end

    it 'passes disabled AI to the cropper when the per-record flag is enabled' do
      car.update!(skip_upscaler: true)
      attach_photo!(car)
      cropped_file = build_temp_image(width: 360, height: 360)
      crop_params = { crop_x: '0.1', crop_y: '0.2', crop_w: '0.3', crop_h: '0.4' }

      expect(ImageCropperService).to receive(:crop)
        .with(
          anything,
          anything,
          padding: 0,
          minimum_side: ImageUpscalerService.default_minimum_side,
          upscale: { use_ai: false, local_fallback: false }
        )
        .and_return(cropped_file)
      allow(YoloDetectionService).to receive(:classify_color).and_return(nil)

      described_class.new.perform(user.id.to_s, car.id.to_s, crop_params)

      expect(Car.find(car.id).photo_processing_status).to eq('completed')
    end

    it 'marks the car as error when image processing fails' do
      attach_photo!(car)

      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .and_raise(StandardError, 'upscaler failed')

      described_class.new.perform(user.id.to_s, car.id.to_s)

      failed_car = Car.find(car.id)
      expect(failed_car.photo_processing_status).to eq('error')
      expect(failed_car.photo_processing_crop?).to be false
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        "cars_#{user.id}",
        target: "car_#{car.id}",
        partial: 'cars/car',
        locals: { car: failed_car }
      ).at_least(:once)
    end
  end
end

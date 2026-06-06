# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DetectedItemImageProcessingJob do
  let(:user) { create(:user) }
  let(:autodetection) { create(:autodetection, user: user) }
  let(:detected_item) { create(:detected_item, autodetection: autodetection, image_processing_status: 'pending') }

  def cropped_file
    Rails.root.join('spec/fixtures/files/car_sample.jpg').open
  end

  describe '#perform' do
    it 'crops and classifies the detected item in the background' do
      file = cropped_file

      expect(ImageCropperService).to receive(:crop)
        .with(
          anything,
          detected_item.position_data['vertices'],
          padding: 0,
          minimum_side: ImageCropperService.default_minimum_side,
          upscale: { use_ai: true, local_fallback: true }
        )
        .and_return(file)
      expect(YoloDetectionService).to receive(:classify)
        .with(file.path)
        .and_return(label: 'Manual car', color: 'Azul')

      described_class.new.perform(user.id.to_s, detected_item.id.to_s)

      processed_item = DetectedItem.find(detected_item.id)
      expect(processed_item.label).to eq('Manual car')
      expect(processed_item.color).to eq('Azul')
      expect(processed_item.cropped_photo).to be_present
      expect(processed_item.image_processing_status).to eq('completed')
    end

    it 'preserves submitted attributes when processing an adjusted selection' do
      file = cropped_file
      detected_item.update!(color: 'Vermelho')

      allow(ImageCropperService).to receive(:crop).and_return(file)
      allow(YoloDetectionService).to receive(:classify).and_return(label: 'AI label', color: 'Azul')

      described_class.new.perform(
        user.id.to_s,
        detected_item.id.to_s,
        name: 'User name',
        color: 'Verde',
        brand: 'Hot Wheels',
        manufacturer: 'Porsche',
        year: '1998',
        size: '1:64'
      )

      processed_item = DetectedItem.find(detected_item.id)
      expect(processed_item.label).to eq('User name')
      expect(processed_item.color).to eq('Verde')
      expect(processed_item.brand).to eq('Hot Wheels')
      expect(processed_item.manufacturer).to eq('Porsche')
      expect(processed_item.year).to eq(1998)
      expect(processed_item.size).to eq('1:64')
    end

    it 'honors the user AI upscaling preference' do
      user.update!(ai_upscaling_enabled: false)
      file = cropped_file

      expect(ImageCropperService).to receive(:crop)
        .with(
          anything,
          anything,
          padding: 0,
          minimum_side: ImageCropperService.default_minimum_side,
          upscale: { use_ai: false, local_fallback: true }
        )
        .and_return(file)
      allow(YoloDetectionService).to receive(:classify).and_return({})

      described_class.new.perform(user.id.to_s, detected_item.id.to_s)

      expect(DetectedItem.find(detected_item.id).image_processing_status).to eq('completed')
    end

    it 'marks the detected item as error when processing fails' do
      allow(ImageCropperService).to receive(:crop).and_raise(ImageUpscalerService::UpscaleError, 'upscaler failed')

      described_class.new.perform(user.id.to_s, detected_item.id.to_s)

      failed_item = DetectedItem.find(detected_item.id)
      expect(failed_item.image_processing_status).to eq('error')
      expect(failed_item.image_processing_error).to eq('upscaler failed')
    end

    it 'does not process detected items from another user' do
      other_user = create(:user)

      expect(ImageCropperService).not_to receive(:crop)

      described_class.new.perform(other_user.id.to_s, detected_item.id.to_s)

      expect(DetectedItem.find(detected_item.id).image_processing_status).to eq('pending')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutodetectJob do
  let(:user) { create(:user) }
  let(:autodetection) { create(:autodetection, user: user) }

  def cropped_file
    Rails.root.join('spec/fixtures/files/car_sample.jpg').open
  end

  describe '#perform' do
    it 'processa a imagem e cria detected items vinculados a autodetection sem upscaler' do
      allow(YoloDetectionService).to receive_messages(
        service_configured?: true,
        analyze: [
          {
            label: 'YOLO car',
            score: 0.99,
            color: 'blue',
            vertices: [{ x: 0.1, y: 0.1 }, { x: 0.9, y: 0.9 }]
          }
        ]
      )
      file = cropped_file

      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
      expect(ImageCropperService).to receive(:crop)
        .with(
          autodetection.photo.path,
          anything,
          minimum_side: ImageCropperService.default_minimum_side,
          upscale: { use_ai: false, local_fallback: false }
        )
        .and_return(file)

      expect do
        described_class.new.perform(autodetection.id.to_s)
      end.to(
        change(DetectedItem, :count).by(1).and(
          change { UsageMetric.values_for(['yolo_detected_items']).fetch('yolo_detected_items') }.from(0).to(1)
        )
      )

      autodetection.reload
      detected_item = autodetection.detected_items.first

      expect(autodetection.status).to eq('to_verify')
      expect(autodetection.photo_upscale_strategy).to be_nil
      expect(autodetection.enhanced_photo).not_to be_present
      expect(detected_item.label).to eq(I18n.t('autodetections.detected_item.new_item'))
      expect(detected_item.color).to eq('blue')
      expect(detected_item.skip_upscaler).to be false
      expect(detected_item.cropped_photo_upscale_strategy).to be_nil
      expect(detected_item.cropped_photo_variant).to be_nil
      expect(detected_item.enhanced_cropped_photo).not_to be_present
      expect(detected_item.cropped_photo).to be_present
    end

    it 'analisa a foto original enviada para o YOLO' do
      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
      expect(YoloDetectionService).to receive(:service_configured?).and_return(true)
      expect(YoloDetectionService).to receive(:analyze).with(autodetection.photo.path).and_return([])

      described_class.new.perform(autodetection.id.to_s)

      expect(autodetection.reload.status).to eq('to_verify')
    end

    it 'nao usa upscale local mesmo quando o usuario desabilita IA' do
      user.update!(ai_upscaling_enabled: false)
      allow(YoloDetectionService).to receive_messages(
        service_configured?: true,
        analyze: [
          {
            label: 'YOLO car',
            score: 0.99,
            vertices: [{ x: 0.1, y: 0.1 }, { x: 0.9, y: 0.9 }]
          }
        ]
      )
      file = cropped_file

      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
      expect(ImageCropperService).to receive(:crop)
        .with(
          anything,
          anything,
          minimum_side: ImageCropperService.default_minimum_side,
          upscale: { use_ai: false, local_fallback: false }
        )
        .and_return(file)

      described_class.new.perform(autodetection.id.to_s)

      expect(autodetection.reload.status).to eq('to_verify')
    end

    it 'nao usa upscale quando o registro antigo tem skip_upscaler ativo' do
      autodetection.update!(skip_upscaler: true)
      allow(YoloDetectionService).to receive_messages(
        service_configured?: true,
        analyze: [
          {
            label: 'YOLO car',
            score: 0.99,
            vertices: [{ x: 0.1, y: 0.1 }, { x: 0.9, y: 0.9 }]
          }
        ]
      )
      file = cropped_file

      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
      expect(ImageCropperService).to receive(:crop)
        .with(
          anything,
          anything,
          minimum_side: ImageCropperService.default_minimum_side,
          upscale: { use_ai: false, local_fallback: false }
        )
        .and_return(file)

      described_class.new.perform(autodetection.id.to_s)

      expect(autodetection.reload.detected_items.first.skip_upscaler).to be true
    end

    it 'marca como erro caso o processamento falhe' do
      allow(YoloDetectionService).to receive(:service_configured?).and_return(true)
      allow(YoloDetectionService).to receive(:analyze).and_raise('Simulated YOLO API Error')

      described_class.new.perform(autodetection.id.to_s)

      autodetection.reload
      expect(autodetection.status).to eq('error')
      expect(autodetection.error_message).to eq('Simulated YOLO API Error')
    end
  end
end

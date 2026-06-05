# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutodetectJob do
  let(:user) { create(:user) }
  # O factory de autodetection já usa o test_image.png
  let(:autodetection) { create(:autodetection, user: user) }

  def build_temp_image(width:, height:, filename: 'autodetection.jpg')
    tempfile = Tempfile.new(['upscaled', '.jpg'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(Rails.root.join('spec/fixtures/files/test_image.png'))
    image.resize "#{width}x#{height}!"
    image.write(tempfile.path)
    tempfile.define_singleton_method(:original_filename) { filename }
    tempfile.define_singleton_method(:content_type) { 'image/jpeg' }
    tempfile
  end

  describe '#perform' do
    it 'processa a imagem e cria detected items vinculados à autodetection' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)
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
      allow(GoogleVisionService).to receive(:credentials_configured?).and_return(false)

      # Mock do arquivo retornado pelo cropper
      mock_file_path = Rails.root.join('tmp/mock_crop.jpg')
      File.write(mock_file_path, 'fake content')

      File.open(mock_file_path) do |mock_file|
        expect(ImageCropperService).to receive(:crop)
          .with(
            anything,
            anything,
            minimum_side: ImageCropperService.default_minimum_side,
            upscale: { use_ai: true, local_fallback: true }
          )
          .and_return(mock_file)

        expect do
          described_class.new.perform(autodetection.id.to_s)
        end.to change(DetectedItem, :count).by(1)

        autodetection.reload
        expect(autodetection.status).to eq('to_verify')
        expect(autodetection.detected_items.first.label).to eq(I18n.t('autodetections.detected_item.new_item'))
        expect(autodetection.detected_items.first.cropped_photo).to be_present
      end

      FileUtils.rm_f(mock_file_path)
    end

    it 'prepares the autodetection photo for YOLO in the background job' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('AUTODETECTION_MINIMUM_SIDE', nil).and_return('1440')
      upscaled_file = build_temp_image(width: 1440, height: 1440)

      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(anything, minimum_side: 1440, use_ai: true, local_fallback: true)
        .and_return(upscaled_file)
      expect(YoloDetectionService).to receive(:service_configured?).and_return(true)
      expect(YoloDetectionService).to receive(:analyze).and_return([])

      described_class.new.perform(autodetection.id.to_s)

      saved_autodetection = Autodetection.find(autodetection.id)
      saved_image = MiniMagick::Image.open(saved_autodetection.photo.path)
      expect(saved_image.width).to eq(1440)
      expect(saved_image.height).to eq(1440)
      expect(saved_autodetection.status).to eq('to_verify')
    end

    it 'uses local fallback when the user disables AI upscaling' do
      user.update!(ai_upscaling_enabled: false)
      allow(YoloDetectionService).to receive_messages(service_configured?: true, analyze: [])

      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(anything, minimum_side: AutodetectionService.autodetection_minimum_side, use_ai: false, local_fallback: true)
        .and_return(nil)

      described_class.new.perform(autodetection.id.to_s)

      expect(autodetection.reload.status).to eq('to_verify')
    end

    it 'marca como erro caso o processamento falhe' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)
      allow(YoloDetectionService).to receive(:service_configured?).and_return(true)
      allow(YoloDetectionService).to receive(:analyze).and_raise('Simulated YOLO API Error')

      described_class.new.perform(autodetection.id.to_s)

      autodetection.reload
      expect(autodetection.status).to eq('error')
      expect(autodetection.error_message).to eq('Simulated YOLO API Error')
    end

    it 'marks the autodetection as error when upscaling fails' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed)
        .and_raise(ImageUpscalerService::UpscaleError, 'Upscale indisponivel')

      described_class.new.perform(autodetection.id.to_s)

      autodetection.reload
      expect(autodetection.status).to eq('error')
      expect(autodetection.error_message).to eq('Upscale indisponivel')
    end
  end
end

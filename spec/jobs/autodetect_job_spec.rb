# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutodetectJob do
  let(:user) { create(:user) }
  # O factory de autodetection já usa o test_image.png
  let(:autodetection) { create(:autodetection, user: user) }

  describe '#perform' do
    it 'processa a imagem e cria detected items vinculados à autodetection' do
      allow(YoloDetectionService).to receive(:service_configured?).and_return(true)
      allow(YoloDetectionService).to receive(:analyze).and_return([
                                                                    {
                                                                      label: 'YOLO car',
                                                                      score: 0.99,
                                                                      vertices: [{ x: 0.1, y: 0.1 }, { x: 0.9, y: 0.9 }]
                                                                    }
                                                                  ])
      allow(GoogleVisionService).to receive(:credentials_configured?).and_return(false)

      # Mock do arquivo retornado pelo cropper
      mock_file_path = Rails.root.join('tmp/mock_crop.jpg')
      File.write(mock_file_path, 'fake content')

      File.open(mock_file_path) do |mock_file|
        allow(ImageCropperService).to receive(:crop).and_return(mock_file)

        expect do
          described_class.new.perform(autodetection.id.to_s)
        end.to change(DetectedItem, :count).by(1)

        autodetection.reload
        expect(autodetection.status).to eq('to_verify')
        expect(autodetection.detected_items.first.label).to eq('YOLO car')
        expect(autodetection.detected_items.first.cropped_photo).to be_present
      end

      FileUtils.rm_f(mock_file_path)
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

require 'rails_helper'

RSpec.describe AutodetectJob do
  let(:user) { create(:user) }
  # O factory de autodetection já usa o test_image.png
  let(:autodetection) { create(:autodetection, user: user) }

  describe '#perform' do
    it 'processa a imagem e cria detected items vinculados à autodetection' do
      # Mock dos serviços para evitar chamadas reais e dependência de MiniMagick/Vision
      allow(GoogleVisionService).to receive(:analyze).and_return([
        { label: 'Toy car', score: 0.95, vertices: [{x: 0.1, y: 0.1}, {x: 0.9, y: 0.9}] }
      ])
      
      # Mock do arquivo retornado pelo cropper
      mock_file_path = Rails.root.join('tmp', 'mock_crop.jpg')
      File.write(mock_file_path, "fake content")
      mock_file = File.open(mock_file_path)
      
      allow(ImageCropperService).to receive(:crop).and_return(mock_file)

      expect {
        AutodetectJob.new.perform(autodetection.id.to_s)
      }.to change(DetectedItem, :count).by(1)

      autodetection.reload
      expect(autodetection.status).to eq('to_verify')
      expect(autodetection.detected_items.first.label).to eq('Toy car')
      expect(autodetection.detected_items.first.cropped_photo).to be_present
      
      # Cleanup
      mock_file.close
      File.delete(mock_file_path) if File.exist?(mock_file_path)
    end

    it 'marca como erro caso o processamento falhe' do
      allow(GoogleVisionService).to receive(:analyze).and_raise("Simulated API Error")

      AutodetectJob.new.perform(autodetection.id.to_s)
      
      autodetection.reload
      expect(autodetection.status).to eq('error')
      expect(autodetection.error_message).to eq("Simulated API Error")
    end
  end
end

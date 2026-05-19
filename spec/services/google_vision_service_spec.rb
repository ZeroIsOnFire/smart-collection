# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoogleVisionService do
  let(:photo_path) { Rails.root.join('spec/fixtures/files/test_image.png').to_s }

  describe '.analyze' do
    context 'when credentials are NOT configured' do
      before do
        allow(described_class).to receive(:credentials_configured?).and_return(false)
      end

      it 'returns an empty array and does NOT call Google Cloud Vision' do
        expect(ImageUpscalerService).not_to receive(:upscale_if_needed)
        expect(Google::Cloud::Vision).not_to receive(:image_annotator)

        result = described_class.analyze(photo_path)

        expect(result).to eq([])
      end
    end

    context 'when credentials ARE configured' do
      let(:mock_annotator) { instance_double(Google::Cloud::Vision::V1::ImageAnnotator::Client) }
      let(:mock_response) { double('Response', responses: [mock_individual_res]) }
      let(:mock_individual_res) { double('Res', localized_object_annotations: [mock_annotation]) }
      let(:mock_annotation) do
        double('Annotation',
               name: 'Toy car',
               score: 0.98,
               bounding_poly: double('Poly', normalized_vertices: [
                                       double('V', x: 0.1, y: 0.1),
                                       double('V', x: 0.9, y: 0.1),
                                       double('V', x: 0.9, y: 0.9),
                                       double('V', x: 0.1, y: 0.9)
                                     ]))
      end

      before do
        allow(described_class).to receive_messages(credentials_configured?: true, simulation_mode?: false)
        expect(ImageUpscalerService).to receive(:upscale_if_needed)
          .with(photo_path, minimum_side: ImageUpscalerService::DEFAULT_MINIMUM_SIDE).ordered.and_return(nil)
        expect(ImageUpscalerService).to receive(:upscale_if_needed)
          .with(photo_path, minimum_side: 1080).ordered.and_return(nil)
        allow(Google::Cloud::Vision).to receive(:image_annotator).and_return(mock_annotator)
        allow(mock_annotator).to receive(:object_localization_detection).and_return(mock_response)
      end

      it 'returns an array of detected objects with label, score and vertices' do
        result = described_class.analyze(photo_path)

        expect(result).to be_an(Array)
        expect(result.size).to eq(1)
        expect(result.first[:label]).to eq('Toy car')
        expect(result.first[:score]).to eq(0.98)
      end

      it 'filters labels correctly (only Toy, Car, etc.)' do
        allow(mock_annotation).to receive(:name).and_return('Cup')

        result = described_class.analyze(photo_path)

        expect(result).to be_empty
      end
    end
  end

  describe '.credentials_configured?' do
    it 'returns false if env is missing' do
      allow(ENV).to receive(:fetch).with('GOOGLE_CLOUD_CREDENTIALS_PATH', nil).and_return(nil)

      expect(described_class).not_to be_credentials_configured
    end

    it 'returns false if file does not exist' do
      allow(ENV).to receive(:fetch).with('GOOGLE_CLOUD_CREDENTIALS_PATH', nil).and_return('/tmp/missing.json')

      expect(described_class).not_to be_credentials_configured
    end
  end
end

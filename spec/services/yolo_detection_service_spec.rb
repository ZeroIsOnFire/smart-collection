# frozen_string_literal: true

require 'rails_helper'

RSpec.describe YoloDetectionService do
  let(:photo_path) { Rails.root.join('spec/fixtures/files/car.jpg') }
  let(:service_url) { 'http://yolo-service:8000' }
  let(:api_key) { 'test_key' }

  before do
    allow(ENV).to receive(:fetch).with('YOLO_SERVICE_URL').and_return(service_url)
    allow(ENV).to receive(:fetch).with('YOLO_API_KEY').and_return(api_key)
    allow(ENV).to receive(:fetch).with('OBSERVABILITY_ENABLED', 'false').and_return('false')
    allow(ENV).to receive(:[]).with('YOLO_SERVICE_URL').and_return(service_url)
    allow(ENV).to receive(:[]).with('YOLO_API_KEY').and_return(api_key)

    # Ensure fixture exists or mock File.open
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(photo_path.to_s).and_return(double('File', path: photo_path.to_s, close: nil))
  end

  describe '.analyze' do
    context 'when service returns success' do
      let(:response_body) do
        {
          detections: [
            {
              label: 'car',
              score: 0.95,
              color: 'Azul',
              vertices: [
                { x: 0.1, y: 0.1 },
                { x: 0.4, y: 0.1 },
                { x: 0.4, y: 0.4 },
                { x: 0.1, y: 0.4 }
              ]
            }
          ]
        }.to_json
      end

      before do
        stub_request(:post, "#{service_url}/detect")
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns processed detections' do
        result = described_class.analyze(photo_path.to_s)
        expect(result.first[:label]).to eq('car')
        expect(result.first[:color]).to eq('blue')
        expect(result.first[:vertices].size).to eq(4)
        expect(result.first[:vertices].first[:x]).to eq(0.1)
      end
    end

    context 'when service returns error' do
      before do
        stub_request(:post, "#{service_url}/detect")
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns an empty array' do
        expect(described_class.analyze(photo_path.to_s)).to eq([])
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:post, "#{service_url}/detect").to_raise(StandardError.new('Network error'))
      end

      it 'returns an empty array and logs error' do
        expect(Rails.logger).to receive(:error).with(/YoloDetectionService Exception: Network error/)
        expect(described_class.analyze(photo_path.to_s)).to eq([])
      end
    end
  end

  describe '.classify_color' do
    it 'returns the normalized color returned by the service' do
      stub_request(:post, "#{service_url}/classify_color")
        .to_return(status: 200, body: { color: 'Azul' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect(described_class.classify_color(photo_path.to_s)).to eq('blue')
    end
  end

  describe '.classify' do
    it 'returns normalized classification attributes' do
      stub_request(:post, "#{service_url}/classify")
        .to_return(status: 200, body: { label: 'car', color: 'Azul' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect(described_class.classify(photo_path.to_s)).to eq(label: 'car', color: 'blue')
    end
  end

  describe '.service_configured?' do
    it 'returns true when env vars are present' do
      expect(described_class).to be_service_configured
    end

    it 'returns false when env vars are missing' do
      allow(ENV).to receive(:[]).with('YOLO_SERVICE_URL').and_return(nil)
      expect(described_class).not_to be_service_configured
    end
  end
end

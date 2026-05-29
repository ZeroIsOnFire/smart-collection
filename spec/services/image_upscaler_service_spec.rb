# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImageUpscalerService do
  let(:source_photo_path) { Rails.root.join('spec/fixtures/files/test_image.png').to_s }
  let(:service_url) { 'http://image-upscale-service:8001' }
  let(:upscale_endpoint) { "#{service_url}/upscale?minimum_side=360" }

  def build_small_photo
    tempfile = Tempfile.new(['small_image', '.png'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(source_photo_path)
    image.resize '256x256!'
    image.write(tempfile.path)
    tempfile
  end

  def build_rectangular_photo
    tempfile = Tempfile.new(['rect_image', '.png'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(source_photo_path)
    image.resize '300x180!'
    image.write(tempfile.path)
    tempfile
  end

  describe '.upscale_if_needed' do
    context 'when the image already meets the minimum side' do
      it 'returns nil' do
        image = instance_double(MiniMagick::Image, width: 640, height: 600)
        allow(MiniMagick::Image).to receive(:open).with(source_photo_path).and_return(image)

        result = described_class.upscale_if_needed(source_photo_path, minimum_side: 360)

        expect(result).to be_nil
      end
    end

    context 'when the image is small and the local AI service is unavailable' do
      it 'upscales locally and preserves the image proportion' do
        allow(described_class).to receive(:service_configured?).and_return(false)
        small_photo = build_rectangular_photo

        result = described_class.upscale_if_needed(small_photo.path, minimum_side: 360)

        expect(result).to be_a(Tempfile)
        expect(File).to exist(result.path)

        final_image = MiniMagick::Image.open(result.path)
        expect([final_image.width, final_image.height].min).to be >= 360
        expect(final_image.width).not_to eq(final_image.height)

        result.close
        FileUtils.rm_f(result.path)
        small_photo.close
        small_photo.unlink
      end
    end

    context 'when the local AI service is configured' do
      let(:response_tempfile) { Tempfile.new(['upscale_response', '.png'], Rails.root.join('tmp')) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with('IMAGE_UPSCALE_SERVICE_URL').and_return(service_url)
        allow(ENV).to receive(:fetch).with('IMAGE_UPSCALE_SERVICE_URL').and_return(service_url)
      end

      it 'sends the image to the service and returns the enhanced file' do
        small_photo = build_small_photo
        image = MiniMagick::Image.open(small_photo.path)
        image.resize '420x380!'
        image.write(response_tempfile.path)

        stub_request(:post, upscale_endpoint)
          .to_return(status: 200, body: File.binread(response_tempfile.path), headers: { 'Content-Type' => 'image/png' })

        result = described_class.upscale_if_needed(small_photo.path, minimum_side: 360)

        expect(result).to be_a(Tempfile)
        expect(File).to exist(result.path)

        final_image = MiniMagick::Image.open(result.path)
        expect([final_image.width, final_image.height].min).to be >= 360
      ensure
        result&.close
        FileUtils.rm_f(result.path) if result&.path
        response_tempfile.close
        response_tempfile.unlink
        small_photo&.close
        small_photo.unlink if small_photo
      end
    end

    context 'when the local AI service and API key are configured' do
      let(:response_tempfile) { Tempfile.new(['upscale_response', '.png'], Rails.root.join('tmp')) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with('IMAGE_UPSCALE_SERVICE_URL').and_return(service_url)
        allow(ENV).to receive(:fetch).with('IMAGE_UPSCALE_SERVICE_URL').and_return(service_url)
        allow(ENV).to receive(:[]).with('IMAGE_UPSCALE_API_KEY').and_return('super-secret')
      end

      it 'sends the shared API key to the service' do
        small_photo = build_small_photo
        image = MiniMagick::Image.open(small_photo.path)
        image.resize '420x380!'
        image.write(response_tempfile.path)

        stub_request(:post, upscale_endpoint)
          .with(headers: { 'X-API-Key' => 'super-secret' })
          .to_return(status: 200, body: File.binread(response_tempfile.path), headers: { 'Content-Type' => 'image/png' })

        result = described_class.upscale_if_needed(small_photo.path, minimum_side: 360)

        expect(result).to be_a(Tempfile)
        expect(File).to exist(result.path)
      ensure
        result&.close
        FileUtils.rm_f(result.path) if result&.path
        response_tempfile.close
        response_tempfile.unlink
        small_photo&.close
        small_photo.unlink if small_photo
      end
    end

    context 'when the local AI service is configured but fails' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with('IMAGE_UPSCALE_SERVICE_URL').and_return(service_url)
        allow(ENV).to receive(:fetch).with('IMAGE_UPSCALE_SERVICE_URL').and_return(service_url)
      end

      it 'raises an explicit error instead of falling back locally' do
        small_photo = build_small_photo

        stub_request(:post, upscale_endpoint)
          .to_return(status: 500, body: 'boom')

        expect do
          described_class.upscale_if_needed(small_photo.path, minimum_side: 360)
        end.to raise_error(ImageUpscalerService::UpscaleError, /500/)
      ensure
        small_photo&.close
        small_photo.unlink if small_photo
      end
    end
  end

  describe '.service_configured?' do
    it 'returns true when the env var is present' do
      allow(ENV).to receive(:[]).with('IMAGE_UPSCALE_SERVICE_URL').and_return(service_url)

      expect(described_class.service_configured?).to be_truthy
    end

    it 'returns false when the env var is missing' do
      allow(ENV).to receive(:[]).with('IMAGE_UPSCALE_SERVICE_URL').and_return(nil)

      expect(described_class.service_configured?).to be_falsey
    end
  end
end

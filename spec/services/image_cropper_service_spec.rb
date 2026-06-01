# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImageCropperService do
  let(:photo_path) { Rails.root.join('spec/fixtures/files/test_image.png').to_s }
  let(:vertices) do
    [
      { x: 0.1, y: 0.1 },
      { x: 0.9, y: 0.1 },
      { x: 0.9, y: 0.9 },
      { x: 0.1, y: 0.9 }
    ]
  end

  describe '.crop' do
    it 'invokes the upscaler before cropping small images' do
      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(photo_path, minimum_side: 360, use_ai: true, local_fallback: false)
        .and_return(nil)

      result = described_class.crop(photo_path, vertices)

      expect(result).to be_a(Tempfile)
      expect(File).to exist(result.path)
      expect(result.path).to include('crop_')
      result.close
      FileUtils.rm_f(result.path)
    end

    it 'uses the upscaler again when the cropped image is still too small' do
      narrow_vertices = [
        { x: 0.1, y: 0.1 },
        { x: 0.2, y: 0.1 },
        { x: 0.2, y: 0.2 },
        { x: 0.1, y: 0.2 }
      ]

      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(photo_path, minimum_side: 360, use_ai: true, local_fallback: false)
        .ordered.and_return(nil)
      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(kind_of(String), minimum_side: 360, use_ai: true, local_fallback: false)
        .ordered.and_return(nil)

      result = described_class.crop(photo_path, narrow_vertices)

      expect(result).to be_a(Tempfile)
      expect(File).to exist(result.path)

      final_image = MiniMagick::Image.open(result.path)
      expect(final_image.width).to be >= 360
      expect(final_image.height).to be >= 360
    ensure
      result&.close
      FileUtils.rm_f(result.path) if result&.path
    end

    it 'passes disabled AI and local fallback flags to the upscaler' do
      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(photo_path, minimum_side: 360, use_ai: false, local_fallback: true)
        .and_return(nil)

      result = described_class.crop(photo_path, vertices, upscale: { use_ai: false, local_fallback: true })

      expect(result).to be_a(Tempfile)
    ensure
      result&.close
      FileUtils.rm_f(result.path) if result&.path
    end

    it 'crops the image and returns a Tempfile object' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)

      result = described_class.crop(photo_path, vertices)

      expect(result).to be_a(Tempfile)
      expect(File).to exist(result.path)
      expect(result.path).to include('crop_')

      final_image = MiniMagick::Image.open(result.path)
      expect(final_image.width).to be >= 360
      expect(final_image.height).to be >= 360

      result.close
      FileUtils.rm_f(result.path)
    end

    it 'handles nil or empty vertices gracefully' do
      expect(described_class.crop(photo_path, nil)).to be_nil
      expect(described_class.crop(photo_path, [])).to be_nil
    end

    it 'handles error during cropping gracefully' do
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(nil)
      resolved = File.expand_path(photo_path)
      expect(MiniMagick::Image).to receive(:open).with(resolved).and_raise('MiniMagick error')

      result = described_class.crop(photo_path, vertices)

      expect(result).to be_nil
    end
  end
end

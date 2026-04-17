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
    it 'crops the image and returns a File object' do
      # We test that it produces a file and uses the provided vertices
      result = ImageCropperService.crop(photo_path, vertices)
      
      expect(result).to be_a(File)
      expect(File.exist?(result.path)).to be_truthy
      expect(result.path).to include('crop_')
      
      # Clean up after test
      result.close
      File.delete(result.path) if File.exist?(result.path)
    end

    it 'handles nil or empty vertices gracefully' do
      expect(ImageCropperService.crop(photo_path, nil)).to be_nil
      expect(ImageCropperService.crop(photo_path, [])).to be_nil
    end

    it 'handles error during cropping gracefully' do
      expect(MiniMagick::Image).to receive(:open).and_raise("MiniMagick error")
      result = ImageCropperService.crop(photo_path, vertices)
      expect(result).to be_nil
    end
  end
end

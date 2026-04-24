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
    it 'crops the image and returns a Tempfile object' do
      # We test that it produces a file and uses the provided vertices
      result = described_class.crop(photo_path, vertices)

      expect(result).to be_a(Tempfile)
      expect(File).to exist(result.path)
      expect(result.path).to include('crop_')

      # Clean up after test
      result.close
      FileUtils.rm_f(result.path)
    end

    it 'handles nil or empty vertices gracefully' do
      expect(described_class.crop(photo_path, nil)).to be_nil
      expect(described_class.crop(photo_path, [])).to be_nil
    end

    it 'handles error during cropping gracefully' do
      # Pre-resolve path to match against expectation
      resolved = File.expand_path(photo_path)
      expect(MiniMagick::Image).to receive(:open).with(resolved).and_raise('MiniMagick error')
      result = described_class.crop(photo_path, vertices)
      expect(result).to be_nil
    end
  end
end

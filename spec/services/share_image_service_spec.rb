# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShareImageService do
  describe '#generate' do
    it 'generates a PNG for a car' do
      car = create(:car, name: 'Share Porsche')

      png = described_class.new(record: car, kind: :car).generate

      expect(png).to start_with("\x89PNG".b)
    end

    it 'generates portrait PNGs without cropping the canvas back to square' do
      item = create(:wishlist_item, name: 'Share Wish')
      item.photo = fixture_file_upload('car_sample.jpg', 'image/jpeg')
      item.save!

      png = described_class.new(record: item, kind: :wishlist_item).generate

      expect(png).to start_with("\x89PNG".b)
      Tempfile.create(['share_image_spec', '.png']) do |file|
        file.binmode
        file.write(png)
        file.rewind

        image = MiniMagick::Image.open(file.path)
        expect(image.dimensions).to eq([1080, 1350])
      end
    end

    it 'generates a PNG for a wishlist list' do
      user = create(:user)
      create(:wishlist_item, user: user)

      png = described_class.new(record: user.wishlist_items, kind: :wishlist, title: 'Wishlist').generate

      expect(png).to start_with("\x89PNG".b)
    end
  end
end

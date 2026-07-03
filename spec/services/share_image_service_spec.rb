# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShareImageService do
  describe '#generate' do
    it 'generates a PNG for a car' do
      car = create(:car, name: 'Share Porsche')

      png = described_class.new(record: car, kind: :car).generate

      expect(png).to start_with("\x89PNG".b)
      Tempfile.create(['share_image_dark_spec', '.png']) do |file|
        file.binmode
        file.write(png)
        file.rewind

        image = MiniMagick::Image.open(file.path)
        expect(image.get_pixels[0][0]).to eq([15, 20, 23])
      end
    end

    it 'includes car record details without AI upscale metadata' do
      car = create(
        :car,
        name: 'Share Porsche',
        brand: 'Mini GT',
        size: '1:64',
        year: 2024,
        color: 'Azul',
        tags: %w[premium coupe],
        observations: 'Edicao especial',
        photo_upscale_strategy: 'ai',
        photo_variant: 'ai'
      )

      lines = described_class.new(record: car, kind: :car).send(:lines).pluck(:text)

      expect(lines).to include('Share Porsche')
      expect(lines).to include("#{I18n.t('activerecord.attributes.car.brand')}: Mini GT")
      expect(lines).to include("#{I18n.t('activerecord.attributes.car.size')}: 1:64")
      expect(lines).to include("#{I18n.t('activerecord.attributes.car.year')}: 2024")
      expect(lines).to include("#{I18n.t('activerecord.attributes.car.color')}: Azul")
      expect(lines).to include("#{I18n.t('activerecord.attributes.car.tags')}: premium, coupe")
      expect(lines).to include("#{I18n.t('activerecord.attributes.car.observations')}: Edicao especial")
      expect(lines.join(' ')).not_to include(I18n.t('cars.show.photo_upscaled_by_ai'))
      expect(lines.join(' ')).not_to include(I18n.t('cars.show.photo_upscaled_by_ai_tooltip'))
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

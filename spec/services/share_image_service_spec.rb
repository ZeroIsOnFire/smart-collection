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
      metadata = [
        "#{I18n.t('share_images.car_fields.brand')} Mini GT",
        "#{I18n.t('share_images.car_fields.scale')} 1:64",
        "#{I18n.t('share_images.car_fields.year')} 2024",
        "#{I18n.t('share_images.car_fields.color')} Azul",
        "#{I18n.t('share_images.car_fields.tags')} premium, coupe"
      ].join('  |  ')

      expect(lines).to include('Share Porsche')
      expect(lines).to include(metadata)
      expect(lines).to include(I18n.t('share_images.car_fields.observations'))
      expect(lines).to include('Edicao especial')
      expect(lines).not_to include(I18n.t('share_images.badges.collection'))
      expect(lines.join(' ')).not_to include(I18n.t('cars.show.photo_upscaled_by_ai'))
      expect(lines.join(' ')).not_to include(I18n.t('cars.show.photo_upscaled_by_ai_tooltip'))
    end

    it 'wraps long car observations into bounded share image lines' do
      car = create(
        :car,
        observations: 'Versao padrao azul, realmente muito bonito, body kit esquisito e detalhes extensos para testar o limite da imagem compartilhada'
      )

      lines = described_class.new(record: car, kind: :car).send(:lines).pluck(:text)
      observation_index = lines.index(I18n.t('share_images.car_fields.observations'))
      observation_lines = lines[(observation_index + 1)..].take_while do |text|
        text != I18n.t('share_images.footer_brand', year: Date.current.year)
      end

      expect(observation_lines.size).to be_between(2, 5)
      expect(observation_lines).to all(have_attributes(length: be <= 74))
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

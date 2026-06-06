# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CarsHelper, type: :helper do
  describe '#car_card_photo_style' do
    it 'returns the default cover style without a processing crop' do
      car = build(:car)

      expect(helper.car_card_photo_style(car)).to include('object-fit: cover')
    end

    it 'zooms and offsets the image when the processing crop is present' do
      car = build(
        :car,
        photo_processing_status: 'pending',
        photo_processing_crop_x: 0.1,
        photo_processing_crop_y: 0.2,
        photo_processing_crop_w: 0.5,
        photo_processing_crop_h: 0.4
      )

      style = helper.car_card_photo_style(car)

      expect(style).to include('position: absolute')
      expect(style).to include('width: 200.0000%')
      expect(style).to include('height: 250.0000%')
      expect(style).to include('left: -20.0000%')
      expect(style).to include('top: -50.0000%')
    end
  end
end

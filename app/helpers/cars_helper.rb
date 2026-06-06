# frozen_string_literal: true

module CarsHelper
  def car_card_photo_style(car)
    base_style = 'width: 100%; height: 100%; object-fit: cover; display: block;'
    return base_style unless car.photo_processing_crop?

    crop_x = car.photo_processing_crop_x.to_f.clamp(0.0, 1.0)
    crop_y = car.photo_processing_crop_y.to_f.clamp(0.0, 1.0)
    crop_w = car.photo_processing_crop_w.to_f.clamp(0.01, 1.0)
    crop_h = car.photo_processing_crop_h.to_f.clamp(0.01, 1.0)

    [
      'position: absolute',
      "width: #{number_to_percentage(100 / crop_w, precision: 4)}",
      "height: #{number_to_percentage(100 / crop_h, precision: 4)}",
      "left: -#{number_to_percentage((crop_x / crop_w) * 100, precision: 4)}",
      "top: -#{number_to_percentage((crop_y / crop_h) * 100, precision: 4)}",
      'object-fit: fill',
      'display: block'
    ].join('; ')
  end
end

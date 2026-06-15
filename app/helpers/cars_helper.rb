# frozen_string_literal: true

module CarsHelper
  def car_display_user(car, provided_user = nil)
    return provided_user if provided_user

    signed_user = current_user if respond_to?(:current_user, true)
    signed_user || car.user
  rescue Devise::MissingWarden
    car.user
  end

  def car_ai_display_enabled?(car, user: nil)
    display_user = car_display_user(car, user)
    display_user&.ai_upscaling_enabled? != false
  end

  def car_ai_upscale_relevant?(car)
    source = car.original_photo? ? car.original_photo : car.photo
    return false unless source&.path

    ImageUpscalerService.upscale_needed?(source.path)
  end

  def car_display_photo(car, user: nil)
    ai_display_unavailable = !car_ai_display_enabled?(car, user:) || !car_ai_upscale_relevant?(car)
    return car.original_photo if ai_display_unavailable && car.original_photo?

    car.photo
  end

  def car_display_photo_url(car, user: nil)
    car_photo_url(car, car_display_photo(car, user:))
  end

  def car_photo_url(car, photo)
    url = photo&.url
    return if url.blank?

    separator = url.include?('?') ? '&' : '?'
    "#{url}#{separator}v=#{car.updated_at.to_i}"
  end

  def car_display_photo_upscaled_by_ai?(car, user: nil)
    car_ai_display_enabled?(car, user:) && car_ai_upscale_relevant?(car) && car.photo_upscaled_by_ai?
  end

  def car_show_original_photo_link?(car, user: nil, public_view: false)
    !public_view && car_display_photo_upscaled_by_ai?(car, user:) && car.original_photo_available?
  end

  def car_photo_cache_key(car, user: nil, public_view: false)
    display_user = car_display_user(car, user)
    [
      :photo_display,
      public_view ? :public : :private,
      display_user&.id,
      display_user&.ai_upscaling_enabled?,
      car.photo_variant,
      car.photo_filename,
      car.original_photo_filename,
      car.enhanced_photo_filename
    ]
  end

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

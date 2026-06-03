# frozen_string_literal: true

class AutodetectionService
  AUTODETECTION_MINIMUM_SIDE = 1080
  AUTODETECTION_MINIMUM_SIDE_ENV = 'AUTODETECTION_MINIMUM_SIDE'
  attr_reader :user

  def self.autodetection_minimum_side
    ImageUpscalerService.minimum_side_from_env(AUTODETECTION_MINIMUM_SIDE_ENV, AUTODETECTION_MINIMUM_SIDE)
  end

  def initialize(user)
    @user = user
  end

  def create(params)
    prepared_params, upscaled_file = prepare_photo_for_save(params, minimum_side: self.class.autodetection_minimum_side)
    autodetection = user.autodetections.create(prepared_params)

    AutodetectJob.perform_later(autodetection.id.to_s) if autodetection.persisted?

    autodetection
  rescue ImageUpscalerService::UpscaleError => e
    autodetection = user.autodetections.new(params.to_h.deep_symbolize_keys)
    autodetection.errors.add(:photo, e.message)
    autodetection
  ensure
    cleanup_tempfile(upscaled_file)
  end

  def retry(autodetection_id)
    autodetection = user.autodetections.find(autodetection_id)

    if autodetection.status == 'error'
      autodetection.update!(status: 'pending', error_message: nil)
      AutodetectJob.perform_later(autodetection.id.to_s)
    end

    autodetection
  end

  private

  def prepare_photo_for_save(params, minimum_side:)
    normalized_params = params.to_h.deep_symbolize_keys
    photo = normalized_params[:photo]

    return [normalized_params, nil] if photo.blank?

    upscaled_file = ImageUpscalerService.upscale_if_needed(
      photo,
      minimum_side: minimum_side,
      use_ai: user.ai_upscaling_enabled?,
      local_fallback: true
    )
    normalized_params[:photo] = upscaled_file if upscaled_file

    [normalized_params, upscaled_file]
  end

  def cleanup_tempfile(tempfile)
    return unless tempfile.respond_to?(:close)

    tempfile.close
    tempfile.unlink
  rescue StandardError
    nil
  end
end

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
    autodetection = user.autodetections.create(params.to_h.deep_symbolize_keys)

    AutodetectJob.perform_later(autodetection.id.to_s) if autodetection.persisted?

    autodetection
  end

  def retry(autodetection_id)
    autodetection = user.autodetections.find(autodetection_id)

    if autodetection.status == 'error'
      autodetection.update!(status: 'pending', error_message: nil)
      AutodetectJob.perform_later(autodetection.id.to_s)
    end

    autodetection
  end
end

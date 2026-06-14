# frozen_string_literal: true

class BulkAiUpscaleJob < ApplicationJob
  queue_as :default

  MAX_CONCURRENT_PER_USER = 3

  def perform(user_id)
    user = User.find(user_id)
    return unless enabled_for?(user)

    available_slots(user).times do
      car = next_candidate(user)
      break unless car

      car.skip_upscaler = false
      car.photo_processing_status = 'pending'
      car.photo_processing_error = nil
      car.save!

      CarImageProcessingJob.perform_later(
        user.id.to_s,
        car.id.to_s,
        force_ai_upscale: true,
        bulk_ai_upscale: true
      )
    end
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  private

  def enabled_for?(user)
    user.bulk_ai_upscaling_enabled? &&
      user.ai_upscaling_enabled? &&
      ImageUpscalerService.service_configured?
  end

  def available_slots(user)
    [MAX_CONCURRENT_PER_USER - processing_count(user), 0].max
  end

  def processing_count(user)
    user.cars.where(:photo_processing_status.in => %w[pending processing]).count
  end

  def next_candidate(user)
    user.cars
        .where(:photo_filename.ne => nil)
        .where(:enhanced_photo_filename.in => [nil, ''])
        .where(:photo_processing_status.nin => %w[pending processing])
        .where(:skip_upscaler.ne => true)
        .asc(:created_at)
        .detect { |car| upscale_needed?(car) }
  end

  def upscale_needed?(car)
    source = car.original_photo? ? car.original_photo : car.photo
    return false unless source&.path

    ImageUpscalerService.upscale_needed?(source.path)
  end
end

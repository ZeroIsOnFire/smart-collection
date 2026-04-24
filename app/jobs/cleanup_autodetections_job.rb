# frozen_string_literal: true

class CleanupAutodetectionsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting CleanupAutodetectionsJob...'
    deleted_count = Autodetection.cleanup_old_records
    Rails.logger.info "CleanupAutodetectionsJob finished. Records removed: #{begin
      deleted_count.count
    rescue StandardError
      'N/A'
    end}"
  end
end

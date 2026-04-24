class CleanupAutodetectionsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting CleanupAutodetectionsJob..."
    deleted_count = Autodetection.cleanup_old_records
    Rails.logger.info "CleanupAutodetectionsJob finished. Records removed: #{deleted_count.count rescue 'N/A'}"
  end
end

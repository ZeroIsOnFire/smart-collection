# frozen_string_literal: true

module ObservabilityMetrics
  module_function

  REGISTRY = Prometheus::Client.registry

  def fetch_or_register(name)
    return REGISTRY.get(name) if REGISTRY.exist?(name)

    yield
  end

  HTTP_REQUESTS = fetch_or_register(:smart_collection_http_requests_total) { REGISTRY.counter(:smart_collection_http_requests_total, docstring: 'HTTP requests', labels: %i[method status]) }
  HTTP_DURATION = fetch_or_register(:smart_collection_http_request_duration_seconds) { REGISTRY.histogram(:smart_collection_http_request_duration_seconds, docstring: 'HTTP request duration', labels: [:method]) }
  PROCESS_START = fetch_or_register(:smart_collection_process_start_time_seconds) { REGISTRY.gauge(:smart_collection_process_start_time_seconds, docstring: 'Process start time') }
  SIDEKIQ_QUEUE = fetch_or_register(:smart_collection_sidekiq_queue_size) { REGISTRY.gauge(:smart_collection_sidekiq_queue_size, docstring: 'Sidekiq queue size', labels: [:queue]) }
  SIDEKIQ_PROCESSED = fetch_or_register(:smart_collection_sidekiq_processed_total) { REGISTRY.gauge(:smart_collection_sidekiq_processed_total, docstring: 'Processed Sidekiq jobs') }
  SIDEKIQ_FAILED = fetch_or_register(:smart_collection_sidekiq_failed_total) { REGISTRY.gauge(:smart_collection_sidekiq_failed_total, docstring: 'Failed Sidekiq jobs') }
  SIDEKIQ_RETRIES = fetch_or_register(:smart_collection_sidekiq_retries_size) { REGISTRY.gauge(:smart_collection_sidekiq_retries_size, docstring: 'Sidekiq retry set size') }
  SIDEKIQ_BUSY = fetch_or_register(:smart_collection_sidekiq_busy_workers) { REGISTRY.gauge(:smart_collection_sidekiq_busy_workers, docstring: 'Busy Sidekiq workers') }
  SIDEKIQ_JOBS = fetch_or_register(:smart_collection_sidekiq_jobs_total) { REGISTRY.counter(:smart_collection_sidekiq_jobs_total, docstring: 'Sidekiq job executions', labels: [:result]) }
  SIDEKIQ_DURATION = fetch_or_register(:smart_collection_sidekiq_job_duration_seconds) { REGISTRY.histogram(:smart_collection_sidekiq_job_duration_seconds, docstring: 'Sidekiq job duration') }

  PROCESS_START.set(Time.now.to_f)

  def refresh_sidekiq!
    return unless defined?(Sidekiq::Stats)

    stats = Sidekiq::Stats.new
    SIDEKIQ_PROCESSED.set(stats.processed)
    SIDEKIQ_FAILED.set(stats.failed)
    SIDEKIQ_RETRIES.set(Sidekiq::RetrySet.new.size)
    SIDEKIQ_BUSY.set(Sidekiq::Workers.new.size)
    # rubocop:disable Rails/FindEach
    Sidekiq::Queue.all.each { |queue| SIDEKIQ_QUEUE.set(queue.size, labels: { queue: queue.name }) }
    # rubocop:enable Rails/FindEach
  rescue RedisClient::Error, Sidekiq::Error => e
    Rails.logger.warn("Observability metrics unavailable: #{e.class}")
  end
end

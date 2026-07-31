# frozen_string_literal: true

require 'sidekiq/api'

module ObservabilityMetrics
  module_function

  REGISTRY = Prometheus::Client.registry
  SIDEKIQ_DURATION_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].freeze
  SIDEKIQ_DURATION_KEY_PREFIX = 'smart_collection:observability:sidekiq:duration'

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
  PROCESS_START.set(Time.now.to_f)

  def refresh_sidekiq!
    stats = Sidekiq::Stats.new
    SIDEKIQ_PROCESSED.set(stats.processed)
    SIDEKIQ_FAILED.set(stats.failed)
    SIDEKIQ_RETRIES.set(Sidekiq::RetrySet.new.size)
    SIDEKIQ_BUSY.set(Sidekiq::Workers.new.size)
    # rubocop:disable Rails/FindEach
    Sidekiq::Queue.all.each { |queue| SIDEKIQ_QUEUE.set(queue.size, labels: { queue: queue.name }) }
    # rubocop:enable Rails/FindEach
    { processed: stats.processed, failed: stats.failed, duration: sidekiq_duration_snapshot }
  rescue RedisClient::Error => e
    Rails.logger.warn("Observability metrics unavailable: #{e.class}")
    nil
  end

  def record_sidekiq_duration(duration)
    Sidekiq.redis do |redis|
      redis.call('INCR', sidekiq_duration_key(:count))
      redis.call('INCRBYFLOAT', sidekiq_duration_key(:sum), duration)
      SIDEKIQ_DURATION_BUCKETS.each do |bucket|
        redis.call('INCR', sidekiq_duration_key(:bucket, bucket)) if duration <= bucket
      end
    end
  rescue RedisClient::Error => e
    Rails.logger.warn("Sidekiq duration metric unavailable: #{e.class}")
  end

  def sidekiq_execution_metrics(snapshot)
    return '' unless snapshot

    duration = snapshot.fetch(:duration)
    lines = [
      '# HELP smart_collection_sidekiq_jobs_total Sidekiq job executions',
      '# TYPE smart_collection_sidekiq_jobs_total counter',
      "smart_collection_sidekiq_jobs_total{result=\"success\"} #{snapshot.fetch(:processed)}",
      "smart_collection_sidekiq_jobs_total{result=\"error\"} #{snapshot.fetch(:failed)}",
      '# HELP smart_collection_sidekiq_job_duration_seconds Sidekiq job duration',
      '# TYPE smart_collection_sidekiq_job_duration_seconds histogram'
    ]

    SIDEKIQ_DURATION_BUCKETS.each do |bucket|
      lines << "smart_collection_sidekiq_job_duration_seconds_bucket{le=\"#{bucket}\"} #{duration.fetch(:buckets).fetch(bucket)}"
    end
    lines << "smart_collection_sidekiq_job_duration_seconds_bucket{le=\"+Inf\"} #{duration.fetch(:count)}"
    lines << "smart_collection_sidekiq_job_duration_seconds_sum #{duration.fetch(:sum)}"
    lines << "smart_collection_sidekiq_job_duration_seconds_count #{duration.fetch(:count)}"
    "#{lines.join("\n")}\n"
  end

  def sidekiq_duration_snapshot
    Sidekiq.redis do |redis|
      {
        count: redis.call('GET', sidekiq_duration_key(:count)).to_i,
        sum: redis.call('GET', sidekiq_duration_key(:sum)).to_f,
        buckets: SIDEKIQ_DURATION_BUCKETS.index_with { |bucket| redis.call('GET', sidekiq_duration_key(:bucket, bucket)).to_i }
      }
    end
  end

  def sidekiq_duration_key(type, bucket = nil)
    return "#{SIDEKIQ_DURATION_KEY_PREFIX}:#{type}" unless bucket

    "#{SIDEKIQ_DURATION_KEY_PREFIX}:bucket:#{bucket}"
  end
end

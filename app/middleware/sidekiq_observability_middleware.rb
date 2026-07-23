# frozen_string_literal: true

class SidekiqObservabilityMiddleware
  def call(_worker, job, queue)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    context = OpenTelemetry.propagation.extract(job)

    OpenTelemetry::Context.with_current(context) do
      Observability.in_span('Sidekiq job', { 'messaging.system' => 'sidekiq', 'messaging.destination.name' => queue }) do
        yield.tap do
          ObservabilityMetrics::SIDEKIQ_JOBS.increment(labels: { result: 'success' }) if Observability.enabled?
        end
      end
    end
  rescue StandardError
    ObservabilityMetrics::SIDEKIQ_JOBS.increment(labels: { result: 'error' }) if Observability.enabled?
    raise
  ensure
    ObservabilityMetrics::SIDEKIQ_DURATION.observe(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) if Observability.enabled? && started_at
  end
end

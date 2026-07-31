# frozen_string_literal: true

class SidekiqObservabilityMiddleware
  def call(_worker, job, queue, &block)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    context = OpenTelemetry.propagation.extract(job)

    OpenTelemetry::Context.with_current(context) do
      Observability.in_span('Sidekiq job', { 'messaging.system' => 'sidekiq', 'messaging.destination.name' => queue }) do
        block.call
      end
    end
  ensure
    ObservabilityMetrics.record_sidekiq_duration(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) if Observability.enabled? && started_at
  end
end

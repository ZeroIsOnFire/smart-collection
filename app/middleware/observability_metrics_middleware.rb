# frozen_string_literal: true

class ObservabilityMetricsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    method = env.fetch('REQUEST_METHOD', 'UNKNOWN')

    Observability.in_span("HTTP #{method}", { 'http.request.method' => method }) do |span|
      status, headers, body = @app.call(env)
      span&.set_attribute('http.response.status_code', status)
      record(method, status, started_at)
      [status, headers, body]
    end
  rescue StandardError
    record(method, 500, started_at)
    raise
  end

  private

  def record(method, status, started_at)
    return unless Observability.enabled?

    ObservabilityMetrics::HTTP_REQUESTS.increment(labels: { method: method, status: status.to_s })
    ObservabilityMetrics::HTTP_DURATION.observe(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at, labels: { method: method })
  end
end

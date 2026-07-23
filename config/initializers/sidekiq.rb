# frozen_string_literal: true

require Rails.root.join('app/middleware/sidekiq_observability_middleware')
require Rails.root.join('app/middleware/sidekiq_trace_context_middleware')

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1') }
  config.server_middleware do |chain|
    chain.add SidekiqObservabilityMiddleware
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1') }
  config.client_middleware do |chain|
    chain.add SidekiqTraceContextMiddleware
  end
end

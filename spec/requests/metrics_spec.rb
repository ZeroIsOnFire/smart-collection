# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics', type: :request do
  around do |example|
    original_value = ENV.fetch('OBSERVABILITY_ENABLED', nil)
    example.run
    ENV['OBSERVABILITY_ENABLED'] = original_value
  end

  it 'does not expose metrics when observability is disabled' do
    ENV['OBSERVABILITY_ENABLED'] = 'false'

    get '/metrics'

    expect(response).to have_http_status(:not_found)
  end

  it 'exposes Prometheus metrics when observability is enabled' do
    ENV['OBSERVABILITY_ENABLED'] = 'true'

    get '/metrics'

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to start_with('text/plain')
    expect(response.body).to include('smart_collection_process_start_time_seconds')
  end

  describe 'GET /metrics' do
    it 'exports the Sidekiq execution metrics collected from Redis' do
      snapshot = {
        processed: 12,
        failed: 2,
        duration: { count: 0, sum: 0.0, buckets: ObservabilityMetrics::SIDEKIQ_DURATION_BUCKETS.index_with(0) }
      }
      allow(Observability).to receive(:enabled?).and_return(true)
      allow(ObservabilityMetrics).to receive(:refresh_sidekiq!).and_return(snapshot)
      expect(ObservabilityMetrics::HTTP_REQUESTS).not_to receive(:increment)

      get '/metrics'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('smart_collection_sidekiq_jobs_total{result="success"} 12')
      expect(response.body).to include('smart_collection_sidekiq_job_duration_seconds_count 0')
    end
  end
end

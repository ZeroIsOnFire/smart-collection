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
end

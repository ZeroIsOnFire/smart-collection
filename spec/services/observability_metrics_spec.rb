# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObservabilityMetrics do
  describe '.sidekiq_execution_metrics' do
    it 'serializes Sidekiq counters and duration histogram in Prometheus format' do
      buckets = described_class::SIDEKIQ_DURATION_BUCKETS.index_with(0).merge(0.1 => 1)
      snapshot = { processed: 12, failed: 2, duration: { count: 1, sum: 0.1, buckets: buckets } }

      output = described_class.sidekiq_execution_metrics(snapshot)

      expect(output).to include('smart_collection_sidekiq_jobs_total{result="success"} 12')
      expect(output).to include('smart_collection_sidekiq_jobs_total{result="error"} 2')
      expect(output).to include('smart_collection_sidekiq_job_duration_seconds_bucket{le="0.1"} 1')
      expect(output).to include('smart_collection_sidekiq_job_duration_seconds_bucket{le="+Inf"} 1')
      expect(output).to include('smart_collection_sidekiq_job_duration_seconds_sum 0.1')
    end

    it 'does not expose execution metrics when Redis is unavailable' do
      expect(described_class.sidekiq_execution_metrics(nil)).to eq('')
    end
  end

  describe '.record_sidekiq_duration' do
    it 'stores cumulative duration data in Redis' do
      redis = instance_double(RedisClient)
      allow(Sidekiq).to receive(:redis).and_yield(redis)
      allow(redis).to receive(:call)

      described_class.record_sidekiq_duration(0.1)

      expect(redis).to have_received(:call).with('INCR', 'smart_collection:observability:sidekiq:duration:count')
      expect(redis).to have_received(:call).with('INCRBYFLOAT', 'smart_collection:observability:sidekiq:duration:sum', 0.1)
      expect(redis).to have_received(:call).with('INCR', 'smart_collection:observability:sidekiq:duration:bucket:0.1')
      expect(redis).not_to have_received(:call).with('INCR', 'smart_collection:observability:sidekiq:duration:bucket:0.05')
    end
  end
end

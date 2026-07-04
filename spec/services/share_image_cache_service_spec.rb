# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShareImageCacheService do
  describe '.fetch' do
    it 'reuses generated car share images until the cache is cleared' do
      cache = ActiveSupport::Cache::MemoryStore.new
      car = create(:car)
      generator = instance_double(ShareImageService, generate: 'cached-png')

      allow(ShareImageService).to receive(:new).with(record: car, kind: :car).and_return(generator)

      first = described_class.fetch(record: car, kind: :car, cache:)
      second = described_class.fetch(record: car, kind: :car, cache:)

      expect(first).to eq('cached-png')
      expect(second).to eq('cached-png')
      expect(generator).to have_received(:generate).once

      described_class.clear(record: car, kind: :car, cache:)
      described_class.fetch(record: car, kind: :car, cache:)

      expect(generator).to have_received(:generate).twice
    end
  end
end

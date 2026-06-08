# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsageMetric do
  describe '.record!' do
    it 'creates and increments a named counter' do
      expect do
        described_class.record!('cars_created')
      end.to change { described_class.values_for(['cars_created']).fetch('cars_created') }.from(0).to(1)

      described_class.record!('cars_created', by: 2)

      expect(described_class.values_for(['cars_created']).fetch('cars_created')).to eq(3)
    end
  end
end

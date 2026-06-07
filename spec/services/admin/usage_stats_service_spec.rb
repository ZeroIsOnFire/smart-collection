# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::UsageStatsService do
  describe '#call' do
    it 'returns current totals and historical counters' do
      user = create(:user)
      create(:car, user: user, detected_via_ai: true)
      autodetection = create(:autodetection, user: user, status: 'to_verify')
      create(:detected_item, autodetection: autodetection, status: 'saved')

      UsageMetric.record!('cars_removed')
      UsageMetric.record!('yolo_detected_items', by: 3)
      UsageMetric.record!('photos_upscaled_ai', by: 2)

      stats = described_class.new.call

      expect(stats[:current]).to include(
        users_count: 1,
        cars_count: 1,
        ai_cars_count: 1,
        detected_items_count: 1,
        active_autodetections_count: 1
      )
      expect(stats[:historical]).to include(
        cars_removed: 1,
        yolo_detected_items: 3,
        photos_upscaled_ai: 2
      )
    end
  end
end

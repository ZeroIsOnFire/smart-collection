# frozen_string_literal: true

module Admin
  class UsageStatsService
    HISTORICAL_COUNTERS = %w[
      users_created
      cars_created
      cars_removed
      yolo_detected_items
      detected_items_removed
      photos_upscaled_ai
      photos_upscaled_local
    ].freeze

    def call
      cars_count = Car.count
      ai_cars_count = Car.where(detected_via_ai: true).count

      {
        current: {
          users_count: User.count,
          cars_count: cars_count,
          ai_cars_count: ai_cars_count,
          ai_cars_percentage: percentage(ai_cars_count, cars_count),
          detected_items_count: DetectedItem.count,
          active_autodetections_count: Autodetection.where(:status.in => %w[pending processing to_verify]).count,
          shared_collections_count: User.where(sharing_enabled: true).count
        },
        historical: UsageMetric.values_for(HISTORICAL_COUNTERS).transform_keys(&:to_sym),
        autodetections_by_status: autodetections_by_status
      }
    end

    private

    def percentage(part, total)
      total.zero? ? 0 : (part.to_f / total * 100).round
    end

    def autodetections_by_status
      raw_stats = Autodetection.collection.aggregate([
                                                       { '$group' => { _id: '$status', count: { '$sum' => 1 } } }
                                                     ]).to_a

      Autodetection::STATUSES.index_with do |status|
        stat = raw_stats.find { |item| item[:_id] == status || item['_id'] == status }.to_h

        (stat[:count] || stat['count']).to_i
      end
    end
  end
end

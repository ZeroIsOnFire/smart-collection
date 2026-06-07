# frozen_string_literal: true

module Admin
  class StatisticsController < DashboardController
    def index
      @stats = Rails.cache.fetch('admin_usage_statistics', expires_in: 5.minutes) do
        UsageStatsService.new.call
      end
    end
  end
end

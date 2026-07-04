# frozen_string_literal: true

module Admin
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :authenticate_admin!

    def index
      @stats = Rails.cache.fetch('admin_dashboard_stats', expires_in: 10.minutes) do
        cars_count = Car.count
        ai_cars_count = Car.where(detected_via_ai: true).count

        {
          users_count: User.count,
          cars_count: cars_count,
          ai_cars_count: ai_cars_count,
          ai_cars_percentage: cars_count.zero? ? 0 : (ai_cars_count.to_f / cars_count * 100).round,
          pending_autodetections: Autodetection.where(:status.in => %w[pending processing to_verify]).count,
          collections_shared: User.where(sharing_enabled: true).count
        }
      end

      @recent_users = Rails.cache.fetch('admin_recent_users', expires_in: 10.minutes) do
        User.desc(:created_at).limit(5).to_a
      end
    end

    private

    def authenticate_admin!
      redirect_to root_path, alert: t('admin.messages.not_authorized') unless current_user.admin?
    end
  end
end

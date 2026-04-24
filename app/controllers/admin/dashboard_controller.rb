module Admin
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :authenticate_admin!

    def index
      @stats = {
        users_count: User.count,
        cars_count: Car.count,
        autodetections_count: Autodetection.count,
        pending_autodetections: Autodetection.where(:status.in => ['pending', 'processing']).count
      }
    end

    private

    def authenticate_admin!
      redirect_to root_path, alert: "Not authorized" unless current_user.admin?
    end
  end
end

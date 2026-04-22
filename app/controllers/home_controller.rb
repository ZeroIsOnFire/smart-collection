class HomeController < ApplicationController
  def index
    if user_signed_in?
      if current_user.admin?
        redirect_to admin_dashboard_path and return
      else
        redirect_to cars_path and return
      end
    end
  end
end

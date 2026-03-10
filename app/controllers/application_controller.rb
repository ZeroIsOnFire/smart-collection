class ApplicationController < ActionController::Base
  layout :set_layout

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_dashboard_path
    else
      root_path
    end
  end

  private

  def set_layout
    if current_user&.admin?
      "admin"
    else
      "application"
    end
  end
end

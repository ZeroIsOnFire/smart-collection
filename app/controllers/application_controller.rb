# frozen_string_literal: true

class ApplicationController < ActionController::Base
  helper :all
  layout :set_layout
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
  end

  def after_sign_in_path_for(resource)
    # Limpa qualquer localização armazenada (como a Home) para garantir o redirecionamento correto
    stored_location_for(resource)

    if resource.admin?
      admin_dashboard_path
    else
      cars_path
    end
  end

  private

  def set_layout
    if current_user&.admin?
      'admin'
    else
      'application'
    end
  end
end

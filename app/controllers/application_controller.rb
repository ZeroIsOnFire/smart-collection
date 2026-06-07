# frozen_string_literal: true

class ApplicationController < ActionController::Base
  helper :all
  layout :set_layout
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Mongoid::Errors::DocumentNotFound, with: :record_not_found

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
  end

  def after_sign_in_path_for(resource)
    # Limpa qualquer localização armazenada (como a Home) para garantir o redirecionamento correto
    stored_location_for(resource)

    return admin_dashboard_path if resource.admin?
    return initial_setup_path if resource.initial_setup_pending?

    cars_path
  end

  private

  def record_not_found
    respond_to do |format|
      format.html do
        flash[:alert] = t('errors.messages.page_not_found', default: 'Página ou item não encontrado.')
        if user_signed_in?
          redirect_to cars_path
        else
          redirect_to root_path
        end
      end
      format.any { head :not_found }
    end
  end

  def set_layout
    if self.class.name.start_with?('Admin::')
      'admin'
    else
      'application'
    end
  end
end

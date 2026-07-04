# frozen_string_literal: true

class RegistrationsController < Devise::RegistrationsController
  protected

  def after_sign_up_path_for(resource)
    resource.update(initial_setup_completed: false)
    initial_setup_path
  end

  def after_inactive_sign_up_path_for(resource)
    resource.update(initial_setup_completed: false)
    initial_setup_path
  end

  private

  def sign_up_params
    params.expect(user: %i[name email password password_confirmation])
  end

  def account_update_params
    params.expect(user: %i[name email locale password password_confirmation current_password])
  end
end

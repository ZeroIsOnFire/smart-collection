# frozen_string_literal: true

class InitialSetupsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_setup_available

  def show; end

  def update
    preferences = initial_setup_params
    preferences.delete(:ai_upscaling_enabled) unless ImageUpscalerService.service_configured?

    if current_user.update(preferences.merge(initial_setup_completed: true))
      redirect_to cars_path, notice: t('initial_setup.messages.completed')
    else
      flash.now[:alert] = t('flash.error')
      render :show, status: :unprocessable_content
    end
  end

  private

  def ensure_setup_available
    return if current_user.initial_setup_pending?

    redirect_to current_user.admin? ? admin_dashboard_path : cars_path, alert: t('flash.unauthorized')
  end

  def initial_setup_params
    params.fetch(:user, {}).permit(:sharing_enabled, :ai_upscaling_enabled)
  end
end

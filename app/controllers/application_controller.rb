# frozen_string_literal: true

class ApplicationController < ActionController::Base
  PORTUGUESE_LANGUAGE_PREFIX = 'pt'
  LOCALE_COOKIE_KEY = :locale
  COOKIE_CONSENT_KEY = :cookie_consent

  helper :all
  layout :set_layout
  around_action :switch_locale
  before_action :configure_permitted_parameters, if: :devise_controller?
  helper_method :current_locale_param

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
        flash[:alert] = t('errors.messages.page_not_found')
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

  def switch_locale(&)
    I18n.with_locale(resolved_locale, &)
  end

  def resolved_locale
    requested_locale.presence || user_locale.presence || cookie_locale.presence || browser_locale.presence || I18n.default_locale
  end

  def requested_locale
    normalized_locale(params[:locale])
  end

  def user_locale
    normalized_locale(current_user&.locale)
  end

  def cookie_locale
    return unless cookies[COOKIE_CONSENT_KEY] == 'accepted'

    normalized_locale(cookies[LOCALE_COOKIE_KEY])
  end

  def browser_locale
    browser_languages = request.get_header('HTTP_ACCEPT_LANGUAGE').to_s.split(',').map do |language|
      language.split(';').first.to_s.strip.downcase
    end

    browser_languages.find { |language| language.start_with?(PORTUGUESE_LANGUAGE_PREFIX) }.presence && 'pt-BR'
  end

  def normalized_locale(locale)
    locale = locale.to_s
    return unless I18n.available_locales.map(&:to_s).include?(locale)

    locale
  end

  def current_locale_param
    { locale: I18n.locale.to_s }
  end

  def localized_return_path(locale)
    target = url_from(params[:return_to]) || root_path
    uri = URI.parse(target)
    query = Rack::Utils.parse_nested_query(uri.query)
    query['locale'] = locale
    uri.query = query.to_query.presence
    uri.to_s
  rescue URI::InvalidURIError
    root_path(locale: locale)
  end
end

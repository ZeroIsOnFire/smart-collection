# frozen_string_literal: true

class LocalesController < ApplicationController
  def update
    locale = normalized_locale(params[:locale])

    if locale
      cookies.permanent[LOCALE_COOKIE_KEY] = { value: locale, same_site: :lax }
      current_user.set(locale: locale) if user_signed_in?
    end

    redirect_to localized_return_path(locale || I18n.locale.to_s)
  end

  private

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

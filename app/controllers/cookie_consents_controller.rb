# frozen_string_literal: true

class CookieConsentsController < ApplicationController
  def create
    locale = normalized_locale(params[:locale]) || I18n.locale.to_s
    cookies.permanent[COOKIE_CONSENT_KEY] = { value: 'accepted', same_site: :lax }
    cookies.permanent[LOCALE_COOKIE_KEY] = { value: locale, same_site: :lax }

    redirect_to localized_return_path(locale)
  end
end

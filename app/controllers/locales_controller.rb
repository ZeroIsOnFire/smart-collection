# frozen_string_literal: true

class LocalesController < ApplicationController
  def update
    locale = normalized_locale(params[:locale])

    if locale
      if user_signed_in?
        current_user.set(locale: locale)
      elsif cookies[COOKIE_CONSENT_KEY] == 'accepted'
        cookies.permanent[LOCALE_COOKIE_KEY] = { value: locale, same_site: :lax }
      end
    end

    redirect_to localized_return_path(locale || I18n.locale.to_s)
  end
end

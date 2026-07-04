# frozen_string_literal: true

module ApplicationHelper
  def javascript_i18n_payload
    backend = I18n.backend
    backend.send(:init_translations) if backend.respond_to?(:init_translations, true)

    {
      locale: I18n.locale.to_s,
      defaultLocale: I18n.default_locale.to_s,
      translations: I18n.available_locales.to_h do |locale|
        [locale.to_s, deep_stringify_translation_tree(backend.send(:translations)[locale] || {})]
      end
    }
  end

  def ai_upscaling_available_for?(user)
    user&.ai_upscaling_enabled? && ImageUpscalerService.service_configured?
  end

  def user_initials(user)
    if user.name?
      user.name.split.map(&:first).join.upcase[0..1]
    else
      user.email.split('@').first[0..1].upcase
    end
  end

  def user_avatar_color(user)
    # Gera uma cor consistente baseada no email
    hash = user.email.hash
    "hsl(#{hash % 360}, 70%, 45%)"
  end

  def display_name(user)
    return user.email unless user.name?

    user.name.gsub(/\s+[a-f0-9]{24}$/i, '')
  end

  def field_error_message(record, attribute)
    record.errors[attribute].to_sentence.presence
  end

  def versioned_public_path(path)
    normalized_path = path.to_s.start_with?('/') ? path.to_s : "/#{path}"
    file_path = Rails.public_path.join(normalized_path.delete_prefix('/'))
    version = File.exist?(file_path) ? File.mtime(file_path).to_i : Time.current.to_i

    "#{normalized_path}?v=#{version}"
  end

  def new_car_from_wishlist_item_path(wishlist_item)
    new_car_path(
      wishlist_item_id: wishlist_item.id.to_s,
      car: WishlistItemToCarAttributesService.new(wishlist_item).to_params
    )
  end

  private

  def deep_stringify_translation_tree(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, child), result|
        result[key.to_s] = deep_stringify_translation_tree(child)
      end
    else
      value
    end
  end
end

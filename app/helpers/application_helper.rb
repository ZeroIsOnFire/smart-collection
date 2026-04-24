# frozen_string_literal: true

module ApplicationHelper
  def user_initials(user)
    if user.name.present?
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
    return user.email if user.name.blank?

    user.name.gsub(/\s+[a-f0-9]{24}$/i, '')
  end
end

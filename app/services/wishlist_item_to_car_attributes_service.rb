# frozen_string_literal: true

class WishlistItemToCarAttributesService
  def initialize(wishlist_item)
    @wishlist_item = wishlist_item
  end

  def to_params
    {
      name: @wishlist_item.name,
      brand: @wishlist_item.brand,
      size: @wishlist_item.scale,
      observations: @wishlist_item.observations,
      remote_photo_url: photo_url
    }.compact_blank
  end

  private

  def photo_url
    return nil unless @wishlist_item.photo?

    @wishlist_item.photo.url
  end
end

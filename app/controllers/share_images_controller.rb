# frozen_string_literal: true

class ShareImagesController < ApplicationController
  before_action :authenticate_user!, except: :public_wishlist

  def car
    car = current_user.cars.find(params[:car_id])

    send_png ShareImageService.new(record: car, kind: :car).generate
  end

  def wishlist_item
    wishlist_item = current_user.wishlist_items.find(params[:wishlist_item_id])

    send_png ShareImageService.new(record: wishlist_item, kind: :wishlist_item).generate
  end

  def wishlist
    wishlist_items = current_user.wishlist_items.desc(:created_at)

    send_png ShareImageService.new(record: wishlist_items, kind: :wishlist, title: t('wishlist_items.index.title')).generate
  end

  def public_wishlist
    user = User.where(wishlist_share_token: params[:token], wishlist_sharing_enabled: true).first
    return head :not_found unless user

    send_png ShareImageService.new(
      record: user.wishlist_items.desc(:created_at),
      kind: :wishlist,
      title: user.wishlist_public_title.presence || t('public_wishlists.show.title', name: user.name)
    ).generate
  end

  private

  def send_png(data)
    send_data data, filename: "smart-collection-share-#{Time.current.strftime('%Y%m%d-%H%M')}.png",
                    type: 'image/png',
                    disposition: 'inline'
  end
end

# frozen_string_literal: true

class ShareImagesController < ApplicationController
  before_action :authenticate_user!, except: %i[public_car public_wishlist public_wishlist_item]

  def car
    car = current_user.cars.find(params[:car_id])

    respond_with_share_image(
      png_path: car_share_image_path(car, format: :png),
      title: car.name,
      data: -> { ShareImageCacheService.fetch(record: car, kind: :car) }
    )
  end

  def wishlist_item
    wishlist_item = current_user.wishlist_items.find(params[:wishlist_item_id])

    respond_with_share_image(
      png_path: wishlist_item_share_image_path(wishlist_item, format: :png),
      title: wishlist_item.name,
      data: -> { ShareImageService.new(record: wishlist_item, kind: :wishlist_item).generate }
    )
  end

  def public_car
    user = User.find_by(share_token: params[:share_token], sharing_enabled: true)
    return head :not_found unless user

    car = user.cars.find(params[:id])
    respond_with_share_image(
      png_path: public_car_share_image_path(user.share_token, car, format: :png),
      title: car.name,
      data: -> { ShareImageCacheService.fetch(record: car, kind: :car) }
    )
  rescue Mongoid::Errors::DocumentNotFound
    head :not_found
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

  def public_wishlist_item
    user = User.where(wishlist_share_token: params[:token], wishlist_sharing_enabled: true).first
    return head :not_found unless user

    wishlist_item = user.wishlist_items.find(params[:id])
    respond_with_share_image(
      png_path: public_wishlist_item_share_image_path(user.wishlist_share_token, wishlist_item, format: :png),
      title: wishlist_item.name,
      data: -> { ShareImageService.new(record: wishlist_item, kind: :wishlist_item).generate }
    )
  rescue Mongoid::Errors::DocumentNotFound
    head :not_found
  end

  private

  def respond_with_share_image(png_path:, title:, data:)
    respond_to do |format|
      format.html do
        render partial: 'share_images/preview_modal',
               locals: { image_path: png_path, title: title },
               formats: [:html]
      end
      format.png { send_png data.call }
    end
  end

  def send_png(data)
    send_data data, filename: "smart-collection-share-#{Time.current.strftime('%Y%m%d-%H%M')}.png",
                    type: 'image/png',
                    disposition: 'inline'
  end
end

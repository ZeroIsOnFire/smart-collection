# frozen_string_literal: true

class PublicWishlistsController < ApplicationController
  layout 'public_showcase'

  def show
    @user = User.where(wishlist_share_token: params[:token], wishlist_sharing_enabled: true).first
    return render_not_found unless @user

    @wishlist_items = filtered_wishlist_items.desc(:created_at)
    @brands = @user.wishlist_items.distinct(:brand).compact_blank.sort
    @scales = @user.wishlist_items.distinct(:scale).compact_blank.sort
  end

  def item
    @user = User.where(wishlist_share_token: params[:token], wishlist_sharing_enabled: true).first
    return render_not_found unless @user

    wishlist_item = @user.wishlist_items.find(params[:id])
    render partial: 'public_wishlists/details_modal', locals: { wishlist_item: wishlist_item, user: @user } if turbo_frame_request?
  rescue Mongoid::Errors::DocumentNotFound
    render_not_found
  end

  private

  def filtered_wishlist_items
    scope = @user.wishlist_items
    scope = filter_wishlist_status(scope)
    scope = scope.where(priority: params[:priority]) if WishlistItem::PRIORITIES.include?(params[:priority])
    scope = scope.where(brand: params[:brand]) if params[:brand].present?
    scope = scope.where(scale: params[:scale]) if params[:scale].present?
    return scope if params[:q].blank?

    pattern = /#{Regexp.escape(params[:q].to_s.strip)}/i
    scope.any_of({ name: pattern }, { brand: pattern }, { scale: pattern })
  end

  def filter_wishlist_status(scope)
    case wishlist_status_filter
    when WishlistItem::STATUS_FILTER_WITHOUT_PURCHASED
      scope.where(:status.ne => 'purchased')
    when *WishlistItem::STATUSES
      scope.where(status: wishlist_status_filter)
    else
      scope
    end
  end

  def wishlist_status_filter
    params.key?(:status) ? params[:status] : WishlistItem::STATUS_FILTER_WITHOUT_PURCHASED
  end

  def render_not_found
    render plain: '404 Not Found', status: :not_found
  end
end

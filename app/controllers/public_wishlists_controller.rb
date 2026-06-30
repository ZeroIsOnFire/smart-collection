# frozen_string_literal: true

class PublicWishlistsController < ApplicationController
  layout 'public_showcase'

  def show
    @user = User.where(wishlist_share_token: params[:token], wishlist_sharing_enabled: true).first
    return render_not_found unless @user

    @wishlist_items = filtered_wishlist_items.desc(:created_at)
    @brands = @user.wishlist_items.distinct(:brand).compact_blank.sort
  end

  private

  def filtered_wishlist_items
    scope = @user.wishlist_items
    scope = scope.where(status: params[:status]) if WishlistItem::STATUSES.include?(params[:status])
    scope = scope.where(priority: params[:priority]) if WishlistItem::PRIORITIES.include?(params[:priority])
    scope = scope.where(brand: params[:brand]) if params[:brand].present?
    scope
  end

  def render_not_found
    render plain: '404 Not Found', status: :not_found
  end
end

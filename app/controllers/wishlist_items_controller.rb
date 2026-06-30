# frozen_string_literal: true

class WishlistItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_wishlist_item, only: %i[edit update destroy add_to_collection]

  def index
    @wishlist_items = filtered_wishlist_items.desc(:created_at)
    @brands = current_user.wishlist_items.distinct(:brand).compact_blank.sort
    @wishlist_item = current_user.wishlist_items.build
  end

  def new
    @wishlist_item = current_user.wishlist_items.build(default_wishlist_item_attributes)
  end

  def edit; end

  def create
    @wishlist_item = current_user.wishlist_items.build(wishlist_item_params)

    if @wishlist_item.save
      redirect_to wishlist_items_path, notice: t('flash.created', resource: t('mongoid.models.wishlist_item.one'))
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @wishlist_item.update(wishlist_item_params)
      redirect_to wishlist_items_path, notice: t('flash.updated', resource: t('mongoid.models.wishlist_item.one'))
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @wishlist_item.destroy

    redirect_to wishlist_items_path, notice: t('flash.deleted', resource: t('mongoid.models.wishlist_item.one'))
  end

  def add_to_collection
    redirect_to new_car_path(
      wishlist_item_id: @wishlist_item.id.to_s,
      car: WishlistItemToCarAttributesService.new(@wishlist_item).to_params
    )
  end

  private

  def set_wishlist_item
    @wishlist_item = current_user.wishlist_items.find(params[:id])
    return if @wishlist_item.user_id.to_s == current_user.id.to_s

    head :not_found
  end

  def filtered_wishlist_items
    scope = current_user.wishlist_items
    scope = scope.where(status: params[:status]) if WishlistItem::STATUSES.include?(params[:status])
    scope = scope.where(priority: params[:priority]) if WishlistItem::PRIORITIES.include?(params[:priority])
    scope = scope.where(brand: params[:brand]) if params[:brand].present?
    return scope if params[:q].blank?

    pattern = /#{Regexp.escape(params[:q].to_s.strip)}/i
    scope.any_of({ name: pattern }, { brand: pattern }, { scale: pattern }, { observations: pattern })
  end

  def wishlist_item_params
    params.expect(wishlist_item: %i[name brand scale observations priority status target_price_cents reference_url photo
                                    remove_photo photo_cache])
  end

  def default_wishlist_item_attributes
    {
      status: 'wanted',
      priority: 'medium'
    }
  end
end

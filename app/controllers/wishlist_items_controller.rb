# frozen_string_literal: true

class WishlistItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_wishlist_item, only: %i[show edit update destroy add_to_collection]

  def index
    @wishlist_items = filtered_wishlist_items.desc(:created_at)
    @brands = current_user.wishlist_items.distinct(:brand).compact_blank.sort
    @wishlist_item = current_user.wishlist_items.build
  end

  def toggle_sharing
    current_user.update(wishlist_sharing_enabled: !current_user.wishlist_sharing_enabled)

    redirect_to wishlist_items_path, notice: t('flash.updated', resource: t('nav.wishlist'))
  end

  def show
    render partial: 'wishlist_items/details_modal', locals: { wishlist_item: @wishlist_item } if turbo_frame_request?
  end

  def new
    @wishlist_item = current_user.wishlist_items.build(default_wishlist_item_attributes)
    render_form_modal(t('wishlist_items.modal.new_title')) if turbo_frame_request?
  end

  def edit
    render_form_modal(t('wishlist_items.modal.edit_title')) if turbo_frame_request?
  end

  def create
    @wishlist_item = current_user.wishlist_items.build(wishlist_item_params)

    if @wishlist_item.save
      respond_to do |format|
        format.html { redirect_to wishlist_items_path, notice: t('flash.created', resource: t('mongoid.models.wishlist_item.one')) }
        format.turbo_stream { render_create_success }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        format.turbo_stream { render_form_modal_stream(t('wishlist_items.modal.new_title')) }
      end
    end
  end

  def update
    if @wishlist_item.update(wishlist_item_params)
      respond_to do |format|
        format.html { redirect_to wishlist_items_path, notice: t('flash.updated', resource: t('mongoid.models.wishlist_item.one')) }
        format.turbo_stream { render_update_success }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_content }
        format.turbo_stream { render_form_modal_stream(t('wishlist_items.modal.edit_title')) }
      end
    end
  end

  def destroy
    @wishlist_item.destroy

    respond_to do |format|
      format.html { redirect_to wishlist_items_path, notice: t('flash.deleted', resource: t('mongoid.models.wishlist_item.one')) }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(view_context.dom_id(@wishlist_item)) +
                             turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                                 locals: success_toast(:deleted))
      end
    end
  end

  def add_to_collection
    redirect_to new_car_path(
      wishlist_item_id: @wishlist_item.id.to_s,
      car: WishlistItemToCarAttributesService.new(@wishlist_item).to_params
    )
  end

  private

  def render_form_modal(title, status: :ok)
    render partial: 'wishlist_items/form_modal',
           locals: { wishlist_item: @wishlist_item, title: title },
           formats: [:html],
           status: status
  end

  def render_form_modal_stream(title)
    render turbo_stream: turbo_stream.update(
      'modal',
      partial: 'wishlist_items/form_modal',
      locals: { wishlist_item: @wishlist_item, title: title, frame: false }
    ), status: :unprocessable_content
  end

  def render_create_success
    render turbo_stream: turbo_stream.prepend(
      'wishlist_grid_inner',
      partial: 'wishlist_items/wishlist_item',
      locals: { wishlist_item: @wishlist_item }
    ) +
                         turbo_stream.remove('wishlist_empty_state') +
                         turbo_stream.update('modal', '') +
                         turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                             locals: success_toast(:created))
  end

  def render_update_success
    render turbo_stream: turbo_stream.replace(view_context.dom_id(@wishlist_item), partial: 'wishlist_items/wishlist_item',
                                                                                   locals: { wishlist_item: @wishlist_item }) +
                         turbo_stream.update('modal', '') +
                         turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                             locals: success_toast(:updated))
  end

  def success_toast(action)
    { type: :notice, message: t("flash.#{action}", resource: t('mongoid.models.wishlist_item.one')) }
  end

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
    params.expect(wishlist_item: %i[name brand scale observations priority status reference_url photo remove_photo
                                    photo_cache])
  end

  def default_wishlist_item_attributes
    {
      status: 'wanted',
      priority: 'medium'
    }
  end
end

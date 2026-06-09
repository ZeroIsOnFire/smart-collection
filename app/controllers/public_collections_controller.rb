# frozen_string_literal: true

class PublicCollectionsController < ApplicationController
  layout 'public_showcase'

  def index
    @user = User.find_by(share_token: params[:share_token], sharing_enabled: true)

    if @user
      @cars = CarService.new(@user).all(index_params)
      @page = @cars.current_page
      @total_count = @cars.total_count
      @has_more = @cars.next_page.present?

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    else
      render_not_found
    end
  end

  def show
    @user = User.find_by(share_token: params[:share_token], sharing_enabled: true)

    if @user
      @car = @user.cars.find(params[:id])
      render partial: 'public_collections/details_modal', locals: { car: @car, user: @user } if turbo_frame_request?
    else
      render_not_found
    end
  rescue Mongoid::Errors::DocumentNotFound
    render_not_found
  end

  private

  def index_params
    params.permit(:q, :page, :per_page)
  end

  def render_not_found
    render plain: '404 Not Found', status: :not_found
  end
end

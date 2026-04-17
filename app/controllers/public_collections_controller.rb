class PublicCollectionsController < ApplicationController
  layout "public_showcase"

  def index
    @user = User.find_by(share_token: params[:share_token], sharing_enabled: true)
    
    if @user
      @cars = CarService.new(@user).all(index_params)
      @page = (index_params[:page] || 1).to_i
      
      scope = params[:q].present? ? CarService.new(@user).search(params[:q]) : @user.cars
      @total_count = scope.count
      
      @has_more = @total_count > @page * 20

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    else
      render_404
    end
  end

  def show
    @user = User.find_by(share_token: params[:share_token], sharing_enabled: true)
    
    if @user
      @car = @user.cars.find(params[:id])
    else
      render_404
    end
  rescue Mongoid::Errors::DocumentNotFound
    render_404
  end

  private

  def index_params
    params.permit(:q, :page, :per_page)
  end

  def render_404
    render plain: "404 Not Found", status: :not_found
  end
end

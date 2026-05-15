# frozen_string_literal: true

class CarsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_car, only: %i[show edit update destroy]

  PER_PAGE = 20

  # GET /cars
  def index
    @autodetections = current_user.autodetections.where(:status.ne => 'completed').order(created_at: :desc)
    @cars = car_service.all(params.merge(per_page: PER_PAGE))
    @page = @cars.current_page
    @has_more = @cars.next_page.present?

    respond_to do |format|
      format.html
      # Apenas renderiza o stream (infinito scroll/busca) se houver parâmetros específicos.
      # Isso evita que redirecionamentos de outras controllers sejam engolidos por acidente.
      format.turbo_stream if params.key?(:page) || params.key?(:query) || params.key?(:view)
    end
  end

  # PATCH /cars/toggle_sharing
  def toggle_sharing
    current_user.update(sharing_enabled: !current_user.sharing_enabled)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('sharing_settings_toggle', partial: 'cars/sharing_settings')
      end
      format.html { redirect_to edit_user_registration_path, notice: 'Configuração de compartilhamento atualizada.' }
    end
  end

  # GET /cars/1
  def show; end

  # GET /cars/new
  def new
    @car = current_user.cars.build(params[:car]&.to_unsafe_h || {})
  end

  # GET /cars/1/edit
  def edit; end

  # POST /cars
  def create
    if params[:detected_item_id].present?
      @detected_item = DetectedItem.find_by(id: params[:detected_item_id])
      # Garante que o item detectado pertence ao usuário atual
      return redirect_to cars_path, alert: 'Item detectado inválido ou não autorizado.' if @detected_item.nil? || @detected_item.autodetection.user_id.to_s != current_user.id.to_s
    end

    # Se vier de um item detectado, garante que a foto seja carregada do arquivo local
    # CarrierWave remote_photo_url falha para arquivos locais / uploads/
    params_to_save = car_params
    if @detected_item
      params_to_save[:photo] = @detected_item.cropped_photo.file.to_file if @detected_item.cropped_photo.present?
      params_to_save[:color] = @detected_item.color if @detected_item.color.present? && params_to_save[:color].blank?
      params_to_save[:detected_via_ai] = true
    end

    @car = car_service.create(params_to_save)

    if @car.persisted?
      if @detected_item
        @detected_item.update(
          status: 'saved',
          car_id: @car.id,
          color: @car.color,
          year: @car.year,
          size: @car.size,
          label: @car.name
        )
        @detected_item.autodetection.check_completion!
      end

      respond_to do |format|
        format.html { redirect_to car_url(@car), notice: 'Carro criado com sucesso.' }
        render_detected_item_replacement(format)
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        render_detected_item_replacement(format)
      end
    end
  end

  # PATCH/PUT /cars/1
  def update
    @car = car_service.update(@car.id, car_params)

    if @car.errors.empty?
      redirect_to car_url(@car), notice: 'Carro atualizado com sucesso.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /cars/1
  def destroy
    car_service.destroy(@car.id)
    redirect_to cars_url, notice: 'Carro deletado com sucesso.'
  end

  private

  def render_detected_item_replacement(format)
    return unless @detected_item

    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        "detected_item_#{@detected_item.id}",
        partial: 'detected_items/detected_item',
        locals: { detected_item: @detected_item }
      )
    end
  end

  def set_car
    @car = Car.find(params[:id])
    raise Mongoid::Errors::DocumentNotFound.new(Car, params[:id]) if @car.user_id != current_user.id
  end

  def car_service
    @car_service ||= CarService.new(current_user)
  end

  def car_params
    params.require(:car).permit(:name, :brand, :manufacturer, :observations, :size, :year, :photo, :remove_photo,
                                :remote_photo_url, :color, :crop_x, :crop_y, :crop_w, :crop_h, :photo_cache)
  end
end

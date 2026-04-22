class CarsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_car, only: %i[ show edit update destroy ]

  PER_PAGE = 20

  # GET /cars
  def index
    @autodetections = current_user.autodetections.where(:status.ne => 'completed').order(created_at: :desc)
    @page = (params[:page] || 1).to_i
    @cars = car_service.all(params.merge(per_page: PER_PAGE))
    
    # Check if there are more results (for infinite scroll)
    # We count based on filtered results if search is present
    total_count = if params[:q].present?
                    car_service.search(params[:q]).count
                  else
                    current_user.cars.count
                  end
    @has_more = total_count > @page * PER_PAGE

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # PATCH /cars/toggle_sharing
  def toggle_sharing
    current_user.update(sharing_enabled: !current_user.sharing_enabled)
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cars_path, notice: "Configuração de compartilhamento atualizada." }
    end
  end

  # GET /cars/1
  def show
  end

  # GET /cars/new
  def new
    @car = current_user.cars.build(params[:car]&.to_unsafe_h || {})
  end

  # GET /cars/1/edit
  def edit
  end

  # POST /cars
  def create
    if params[:detected_item_id].present?
      @detected_item = DetectedItem.find_by(id: params[:detected_item_id])
      # Garante que o item detectado pertence ao usuário atual
      if @detected_item.nil? || @detected_item.autodetection.user_id.to_s != current_user.id.to_s
        return redirect_to cars_path, alert: "Item detectado inválido ou não autorizado."
      end
    end
    
    # Se vier de um item detectado, garante que a foto seja carregada do arquivo local
    # CarrierWave remote_photo_url falha para arquivos locais / uploads/
    params_to_save = car_params
    if @detected_item
      params_to_save[:photo] = File.open(@detected_item.cropped_photo.path) if @detected_item.cropped_photo.present?
      params_to_save[:color] = @detected_item.color if @detected_item.color.present? && params_to_save[:color].blank?
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
        format.html { redirect_to car_url(@car), notice: "Carro criado com sucesso." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "detected_item_#{@detected_item.id}", 
            partial: "detected_items/detected_item", 
            locals: { detected_item: @detected_item }
          )
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "detected_item_#{@detected_item.id}", 
            partial: "detected_items/detected_item", 
            locals: { detected_item: @detected_item }
          )
        end
      end
    end
  end

  # PATCH/PUT /cars/1
  def update
    @car = car_service.update(@car.id, car_params)
    
    if @car.errors.empty?
      redirect_to car_url(@car), notice: "Carro atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /cars/1
  def destroy
    car_service.destroy(@car.id)
    redirect_to cars_url, notice: "Carro deletado com sucesso."
  end

  private

  def set_car
    @car = Car.find(params[:id])
    raise Mongoid::Errors::DocumentNotFound.new(Car, params[:id]) if @car.user_id != current_user.id
  end

  def car_service
    @car_service ||= CarService.new(current_user)
  end

  def car_params
    params.require(:car).permit(:name, :brand, :manufacturer, :observations, :size, :year, :photo, :remove_photo, :remote_photo_url, :color, tags: [])
  end
end

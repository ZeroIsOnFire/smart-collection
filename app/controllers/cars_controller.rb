# frozen_string_literal: true

class CarsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_car, only: %i[show edit update]

  PER_PAGE = 20

  # GET /cars
  def index
    @autodetections = current_user.autodetections.active_recent
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
      format.html { redirect_to edit_user_registration_path, notice: t('flash.updated', resource: t('nav.settings')) }
    end
  end

  # PATCH /cars/toggle_ai_upscaling
  def toggle_ai_upscaling
    return redirect_to edit_user_registration_path unless ImageUpscalerService.service_configured?

    current_user.update(ai_upscaling_enabled: !current_user.ai_upscaling_enabled)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('ai_upscaling_settings_toggle', partial: 'cars/ai_upscaling_settings')
      end
      format.html { redirect_to edit_user_registration_path, notice: t('flash.updated', resource: t('nav.settings')) }
    end
  end

  # GET /cars/1
  def show
    render partial: 'cars/details_modal', locals: { car: @car } if turbo_frame_request?
  end

  # GET /cars/new
  def new
    @car = current_user.cars.build(new_car_params)
    render_form_modal(t('cars.modal.new_title')) if turbo_frame_request?
  end

  # GET /cars/1/edit
  def edit
    render_form_modal(t('cars.modal.edit_title')) if turbo_frame_request?
  end

  # POST /cars
  def create
    if params[:detected_item_id].present?
      @detected_item = DetectedItem.find_by(id: params[:detected_item_id])
      # Garante que o item detectado pertence ao usuário atual
      return redirect_to cars_path, alert: t('flash.unauthorized') if @detected_item.nil? || @detected_item.autodetection.user_id.to_s != current_user.id.to_s
    end

    # Se vier de um item detectado, garante que a foto seja carregada do arquivo local
    # CarrierWave remote_photo_url falha para arquivos locais / uploads/
    params_to_save = car_params
    if @detected_item
      params_to_save[:photo] = @detected_item.cropped_photo.file.to_file if @detected_item.cropped_photo.present?
      params_to_save[:color] = @detected_item.color if @detected_item.color? && params_to_save[:color].blank?
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
          label: @car.name,
          skip_upscaler: @car.skip_upscaler?
        )
        @detected_item.autodetection.check_completion!
      end

      respond_to do |format|
        format.html { redirect_to car_url(@car), notice: t('flash.created', resource: t('activerecord.models.car.one')) }
        if @detected_item
          render_detected_item_replacement(format)
        elsif create_another?
          format.turbo_stream { render_create_another_success }
        else
          format.turbo_stream { render_create_success }
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        if @detected_item
          render_detected_item_replacement(format)
        else
          format.turbo_stream { render_form_modal_stream(t('cars.modal.new_title')) }
        end
      end
    end
  end

  # PATCH/PUT /cars/1
  def update
    @car = car_service.update(@car.id, car_params)

    if @car.errors.empty?
      respond_to do |format|
        format.html { redirect_to car_url(@car), notice: t('flash.updated', resource: t('activerecord.models.car.one')) }
        format.turbo_stream { render_update_success }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_content }
        format.turbo_stream do
          render_form_modal_stream(t('cars.modal.edit_title'))
        end
      end
    end
  end

  # DELETE /cars/1
  def destroy
    car = current_user.cars.find_by(id: params[:id])
    unless car
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: remove_car_cards_stream(params[:id]) +
                               turbo_stream.update('modal', '')
        end
        format.html { redirect_to cars_url, notice: t('flash.deleted', resource: t('activerecord.models.car.one')) }
      end
      return
    end

    car_service.destroy(car.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: remove_car_cards_stream(params[:id]) +
                             turbo_stream.update('modal', '') +
                             turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                                 locals: { type: :notice, message: t('flash.deleted', resource: t('activerecord.models.car.one')) })
      end
      format.html { redirect_to cars_url, notice: t('flash.deleted', resource: t('activerecord.models.car.one')) }
    end
  rescue StandardError => e
    Rails.logger.error "CarsController#destroy failed: #{e.message}"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('modal', '') +
                             turbo_stream.append(
                               'flash_toasts',
                               partial: 'shared/toast',
                               locals: { type: :alert, message: t('flash.error') }
                             ), status: :unprocessable_content
      end
      format.html { redirect_to cars_url, alert: t('flash.error') }
    end
  end

  private

  def render_detected_item_replacement(format)
    return unless @detected_item

    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        "detected_item_#{@detected_item.id}",
        partial: 'detected_items/detected_item',
        locals: { detected_item: @detected_item, car: @car }
      )
    end
  end

  def render_form_modal(title, status: :ok)
    render partial: 'cars/form_modal',
           locals: { car: @car, title: title },
           formats: [:html],
           status: status
  end

  def render_form_modal_stream(title)
    render turbo_stream: turbo_stream.update(
      'modal',
      partial: 'cars/form_modal',
      locals: { car: @car, title: title, frame: false }
    ), status: :unprocessable_content
  end

  def render_create_success
    render turbo_stream: turbo_stream.prepend('cars_grid_inner', partial: 'cars/car', locals: { car: @car }) +
                         turbo_stream.remove('cars_empty_state') +
                         turbo_stream.update('modal', '') +
                         turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                             locals: success_toast(:created))
  end

  def render_create_another_success
    created_car = @car
    @car = current_user.cars.build(default_new_car_attributes)

    render turbo_stream: turbo_stream.prepend('cars_grid_inner', partial: 'cars/car', locals: { car: created_car }) +
                         turbo_stream.remove('cars_empty_state') +
                         turbo_stream.update(
                           'modal',
                           partial: 'cars/form_modal',
                           locals: { car: @car, title: t('cars.modal.new_title'), frame: false }
                         ) +
                         turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                             locals: success_toast(:created))
  end

  def render_update_success
    render turbo_stream: turbo_stream.replace("car_#{@car.id}", partial: 'cars/car', locals: { car: @car }) +
                         turbo_stream.update('modal', '') +
                         turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                             locals: success_toast(:updated))
  end

  def remove_car_cards_stream(car_id)
    safe_car_id = car_id.to_s.gsub(/[^a-zA-Z0-9_-]/, '')

    view_context.turbo_stream_action_tag(:remove, targets: %([data-car-card-id="#{safe_car_id}"]))
  end

  def success_toast(action)
    { type: :notice, message: t("flash.#{action}", resource: t('activerecord.models.car.one')) }
  end

  def create_another?
    params[:commit_action] == 'create_another'
  end

  def set_car
    @car = current_user.cars.find(params[:id])
  end

  def car_service
    @car_service ||= CarService.new(current_user)
  end

  def car_params
    params.require(:car).permit(:name, :brand, :observations, :size, :year, :photo, :remove_photo,
                                :remote_photo_url, :color, :crop_x, :crop_y, :crop_w, :crop_h, :photo_cache,
                                :skip_upscaler)
  end

  def new_car_params
    params.fetch(:car, {}).permit(:name, :brand, :observations, :size, :year, :color, :skip_upscaler)
  end

  def default_new_car_attributes
    latest_car = current_user.cars.desc(:created_at).first
    return {} unless latest_car

    attributes = {
      brand: latest_car.brand,
      size: latest_car.size
    }.compact_blank
    attributes[:skip_upscaler] = true if latest_car.skip_upscaler?
    attributes
  end
end

# frozen_string_literal: true

class DetectedItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_autodetection, only: [:create]
  before_action :set_detected_item, only: %i[reject undo update_selection destroy]
  rescue_from ImageUpscalerService::UpscaleError, with: :handle_upscale_error

  # POST /autodetections/:autodetection_id/detected_items
  def create
    normalized_vertices = normalized_vertices_from_params

    # Recortar imagem
    cropped_file = ImageCropperService.crop(
      @autodetection.photo.path,
      normalized_vertices,
      padding: 0,
      minimum_side: ImageCropperService.default_minimum_side,
      upscale: { use_ai: current_user.ai_upscaling_enabled?, local_fallback: true }
    )

    # Autodetecção completa baseada no recorte manual
    classification = YoloDetectionService.classify(cropped_file.path) if cropped_file

    @detected_item = @autodetection.detected_items.new(
      status: 'pending',
      label: classification[:label].presence || t('autodetections.detected_item.new_item'),
      color: classification[:color],
      position_data: {
        'score' => 1.0, # Manual
        'vertices' => normalized_vertices
      },
      cropped_photo: cropped_file
    )

    if @detected_item.save
      @autodetection.update(status: 'to_verify') if @autodetection.status == 'completed'

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            "detected_items_list_#{@autodetection.id}",
            partial: 'detected_items/detected_item',
            locals: { detected_item: @detected_item }
          )
        end
        format.html { redirect_to @autodetection, notice: t('autodetections.messages.item_added') }
      end
    else
      respond_to do |format|
        format.html { redirect_to @autodetection, alert: t('autodetections.messages.item_error') }
        format.json { render json: @detected_item.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /detected_items/:id
  def destroy
    autodetection = @detected_item.autodetection
    @detected_item.destroy
    autodetection.check_completion!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("detected_item_#{params[:id]}")
      end
      format.html { redirect_back_or_to(root_path, notice: t('autodetections.messages.item_removed')) }
    end
  end

  # PATCH /detected_items/:id/reject
  def reject
    @detected_item.update(status: 'rejected')
    @detected_item.autodetection.check_completion!

    respond_with_replaced_item
  end

  # PATCH /detected_items/:id/undo
  def undo
    DetectedItemService.new.undo(@detected_item, current_user)

    respond_with_replaced_item
  end

  # PATCH /detected_items/:id/update_selection
  def update_selection
    normalized_vertices = normalized_vertices_from_params

    # Recortar novamente sem padding extra
    cropped_file = ImageCropperService.crop(
      @detected_item.autodetection.photo.path,
      normalized_vertices,
      padding: 0,
      minimum_side: ImageCropperService.default_minimum_side,
      upscale: { use_ai: current_user.ai_upscaling_enabled?, local_fallback: true }
    )

    if cropped_file
      # Atualiza position_data e a foto recortada
      new_position_data = @detected_item.position_data.dup
      new_position_data['vertices'] = normalized_vertices

      # Autodetecção completa baseada no novo recorte
      classification = YoloDetectionService.classify(cropped_file.path)

      # Lógica de atualização de cor:
      # Se a cor no formulário for igual à cor atual do item, significa que o usuário não a alterou manualmente.
      # Nesse caso, priorizamos a nova detecção da IA baseada no novo recorte.
      new_color = params[:color]
      new_color = classification[:color] if new_color == @detected_item.color && classification[:color].present?

      @detected_item.update(
        position_data: new_position_data,
        cropped_photo: cropped_file,
        label: params[:name].presence || classification[:label].presence || @detected_item.label,
        color: new_color.presence || @detected_item.color,
        brand: params[:brand],
        manufacturer: params[:manufacturer],
        year: params[:year],
        size: params[:size]
      )
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "detected_item_#{@detected_item.id}",
          partial: 'detected_items/detected_item',
          locals: { detected_item: @detected_item }
        )
      end
      format.html { redirect_back_or_to(root_path) }
    end
  end

  private

  def respond_with_replaced_item
    respond_to do |format|
      format.html { redirect_back_or_to(root_path) }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "detected_item_#{@detected_item.id}",
          partial: 'detected_items/detected_item',
          locals: { detected_item: @detected_item }
        )
      end
    end
  end

  def set_autodetection
    @autodetection = current_user.autodetections.find(params[:autodetection_id])
  end

  def set_detected_item
    @detected_item = DetectedItem.find_by(id: params[:id])

    render json: { error: t('flash.not_found', resource: t('activerecord.models.item.one')) }, status: :not_found and return if @detected_item.nil?

    # Verifica se pertence ao usuário através da autodetection
    return if @detected_item.autodetection.user_id.to_s == current_user.id.to_s

    render json: { error: t('flash.unauthorized') }, status: :unauthorized and return
  end

  # Monta os vértices normalizados (0.0 a 1.0) a partir dos params x, y, width, height
  def normalized_vertices_from_params
    x = params[:x].to_f
    y = params[:y].to_f
    w = params[:width].to_f
    h = params[:height].to_f
    [
      { 'x' => x,     'y' => y },
      { 'x' => x + w, 'y' => y },
      { 'x' => x + w, 'y' => y + h },
      { 'x' => x,     'y' => y + h }
    ]
  end

  def handle_upscale_error(exception)
    message = exception.message.presence || t('flash.error')

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          'flash_toasts',
          partial: 'shared/toast',
          locals: { type: :alert, message: message }
        ), status: :unprocessable_content
      end
      format.html { redirect_back_or_to(@autodetection, alert: message) }
    end
  end
end

# frozen_string_literal: true

class DetectedItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_autodetection, only: [:create]
  before_action :set_detected_item, only: %i[reject undo update_selection destroy]

  # POST /autodetections/:autodetection_id/detected_items
  def create
    normalized_vertices = normalized_vertices_from_params

    # Recortar imagem
    cropped_file = ImageCropperService.crop(@autodetection.photo.path, normalized_vertices, padding: 0)

    @detected_item = @autodetection.detected_items.new(
      status: 'pending',
      label: 'Novo Item',
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
          render turbo_stream: [
            turbo_stream.append(
              "detected_items_list_#{@autodetection.id}",
              partial: 'detected_items/detected_item',
              locals: { detected_item: @detected_item }
            ),
            turbo_stream.append(
              'local_toast_container',
              partial: 'shared/toast',
              locals: { type: 'success', message: 'Item adicionado com sucesso!' }
            )
          ]
        end
        format.html { redirect_to @autodetection, notice: 'Item adicionado manualmente.' }
      end
    else
      respond_to do |format|
        format.html { redirect_to @autodetection, alert: 'Erro ao adicionar item.' }
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
      format.html { redirect_back_or_to(root_path, notice: 'Item removido.') }
    end
  end

  # PATCH /detected_items/:id/reject
  def reject
    @detected_item.update(status: 'rejected')
    @detected_item.autodetection.check_completion!

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

  # PATCH /detected_items/:id/undo
  def undo
    DetectedItemService.new.undo(@detected_item, current_user)

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

  # PATCH /detected_items/:id/update_selection
  def update_selection
    normalized_vertices = normalized_vertices_from_params

    # Recortar novamente sem padding extra
    cropped_file = ImageCropperService.crop(@detected_item.autodetection.photo.path, normalized_vertices, padding: 0)

    if cropped_file
      # Atualiza position_data e a foto recortada
      new_position_data = @detected_item.position_data.dup
      new_position_data['vertices'] = normalized_vertices

      @detected_item.update(
        position_data: new_position_data,
        cropped_photo: cropped_file
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

  def set_autodetection
    @autodetection = current_user.autodetections.find(params[:autodetection_id])
  end

  def set_detected_item
    @detected_item = DetectedItem.find_by(id: params[:id])

    render json: { error: 'Não encontrado' }, status: :not_found and return if @detected_item.nil?

    # Verifica se pertence ao usuário através da autodetection
    return if @detected_item.autodetection.user_id.to_s == current_user.id.to_s

    render json: { error: 'Não autorizado' }, status: :unauthorized and return
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
end

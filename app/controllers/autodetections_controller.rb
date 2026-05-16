# frozen_string_literal: true

class AutodetectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_autodetection, only: %i[show retry destroy]

  def show
    # A view 'show' será vazia por enquanto
  end

  def create
    @autodetection = autodetection_service.create(autodetection_params)

    if @autodetection.persisted?
      # Pode retornar sucesso no Turbo pra não recarregar a página
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend('autodetections_list', partial: 'autodetections/autodetection',
                                                                           locals: { autodetection: @autodetection }) +
                               turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                                   locals: { type: :notice, message: t('autodetections.messages.started') })
        end
        format.html { redirect_to root_path, notice: t('autodetections.messages.started') }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          error_message = @autodetection.errors.full_messages.to_sentence

          render turbo_stream: turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                                   locals: {
                                                                     type: :alert,
                                                                     message: "#{t('activerecord.errors.template.header.one')}: #{error_message}"
                                                                   })
        end
        format.html do
          error_message = @autodetection.errors.full_messages.to_sentence

          redirect_to root_path,
                      alert: "#{t('autodetections.messages.error_starting')}: #{error_message}"
        end
      end
    end
  end

  def destroy
    is_from_show_page = params[:redirect_to_cars].present?
    autodetection_dom_id = "autodetection_#{@autodetection.id}"

    @autodetection.destroy

    respond_to do |format|
      format.turbo_stream do
        if is_from_show_page
          redirect_to cars_path, status: :see_other, notice: t('autodetections.messages.removed')
        else
          render turbo_stream: turbo_stream.remove(autodetection_dom_id) +
                               turbo_stream.append('flash_toasts', partial: 'shared/toast',
                                                                   locals: { type: :notice, message: t('autodetections.messages.deleted') })
        end
      end
      format.html { redirect_to cars_path, notice: t('autodetections.messages.removed') }
    end
  end

  def retry
    autodetection_service.retry(@autodetection.id.to_s)
    redirect_to root_path, notice: t('autodetections.messages.restarted')
  end

  def detect_color
    photo = params[:photo]
    if photo.present?
      color = YoloDetectionService.classify_color(photo.path)
      render json: { color: color }
    else
      render json: { error: t('autodetections.messages.no_photo') }, status: :bad_request
    end
  end

  def classify
    photo = params[:photo]
    if photo.present?
      result = YoloDetectionService.classify(photo.path)
      render json: result
    else
      render json: { error: t('autodetections.messages.no_photo') }, status: :bad_request
    end
  end

  private

  def set_autodetection
    @autodetection = current_user.autodetections.find(params[:id])
  end

  def autodetection_service
    @autodetection_service ||= AutodetectionService.new(current_user)
  end

  def autodetection_params
    params.require(:autodetection).permit(:photo)
  end
end

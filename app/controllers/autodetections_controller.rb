class AutodetectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_autodetection, only: %i[show retry destroy]

  def create
    @autodetection = autodetection_service.create(autodetection_params)

    if @autodetection.persisted?
      # Pode retornar sucesso no Turbo pra não recarregar a página
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("autodetection_form", partial: "autodetections/form_button", locals: { autodetection: Autodetection.new }),
            turbo_stream.append("flash_toasts", partial: "shared/toast", locals: { type: :notice, message: "Autodetect iniciado com sucesso!" })
          ]
        end
        format.html { redirect_to root_path, notice: "Autodetect iniciado!" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("flash_toasts", partial: "shared/toast", locals: { type: :alert, message: "Erro: #{@autodetection.errors.full_messages.to_sentence}" })
        end
        format.html { redirect_to root_path, alert: "Erro ao iniciar Autodetect: #{@autodetection.errors.full_messages.to_sentence}" }
      end
    end
  end

  def show
    # A view 'show' será vazia por enquanto
  end

  def destroy
    @autodetection.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("autodetection_#{@autodetection.id}")
      end
      format.html { redirect_to cars_path, notice: "Autodetecção removida/cancelada." }
    end
  end

  def retry
    autodetection_service.retry(@autodetection.id.to_s)
    redirect_to root_path, notice: "Processo reiniciado."
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

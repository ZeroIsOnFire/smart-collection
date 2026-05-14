# frozen_string_literal: true

class AutodetectJob < ApplicationJob
  queue_as :default

  def perform(autodetection_id)
    autodetection = Autodetection.find(autodetection_id)
    return unless autodetection

    # Atualiza o status para processing, que fará trigger no Turbo Stream
    autodetection.update!(status: 'processing')

    begin
      # 1. Analisar a imagem (Prioriza YOLO local, fallback para Google Vision)
      detected_items_data = []

      if YoloDetectionService.service_configured?
        Rails.logger.info "AutodetectJob: Attempting YOLO detection for autodetection #{autodetection_id}"
        detected_items_data = YoloDetectionService.analyze(autodetection.photo.path)
      end

      # Fallback ou se YOLO não encontrou nada (opcional: Vision é melhor para texto/objetos variados)
      if detected_items_data.empty? && GoogleVisionService.credentials_configured?
        Rails.logger.info "AutodetectJob: Attempting Google Vision detection for autodetection #{autodetection_id}"
        detected_items_data = GoogleVisionService.analyze(autodetection.photo.path)
      end

      Rails.logger.info "AutodetectJob: No items found for autodetection #{autodetection_id}" if detected_items_data.empty?

      # 2. Processar cada item detectado
      detected_items_data.each do |data|
        # Recortar a imagem baseado nas coordenadas retornadas
        cropped_file = ImageCropperService.crop(autodetection.photo.path, data[:vertices])

        next unless cropped_file

        autodetection.detected_items.create!(
          label: 'Veículo',
          position_data: {
            vertices: data[:vertices],
            score: data[:score]
          },
          cropped_photo: cropped_file
        )
        # O arquivo temporário será limpo pelo Rails/CarrierWave se necessário
      end

      # Sucesso - Agora move para 'Para Verificar' para que o usuário possa interagir
      autodetection.update!(status: 'to_verify', error_message: nil)
    rescue StandardError => e
      # Em caso de qualquer pane, salva o erro para visualização do usuário na tela e permite tentar novamente
      Rails.logger.error "AutodetectJob Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      autodetection.update!(status: 'error', error_message: e.message)
    end
  end
end

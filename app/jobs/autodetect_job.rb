class AutodetectJob < ApplicationJob
  queue_as :default

  def perform(autodetection_id)
    autodetection = Autodetection.find(autodetection_id)
    return unless autodetection
    
    # Atualiza o status para processing, que fará trigger no Turbo Stream
    autodetection.update!(status: 'processing')

    begin
      # 1. Analisar a imagem com Google Vision
      detected_items_data = GoogleVisionService.analyze(autodetection.photo.path)
      
      if detected_items_data.empty?
        Rails.logger.info "AutodetectJob: Blue items found for autodetection #{autodetection_id}"
      end

      # 2. Processar cada item detectado
      detected_items_data.each do |data|
        # Recortar a imagem baseado nas coordenadas retornadas
        cropped_file = ImageCropperService.crop(autodetection.photo.path, data[:vertices])
        
        if cropped_file
          autodetection.detected_items.create!(
            label: data[:label],
            position_data: { 
              vertices: data[:vertices], 
              score: data[:score] 
            },
            cropped_photo: cropped_file
          )
          # O arquivo temporário será limpo pelo Rails/CarrierWave se necessário
        end
      end

      # Sucesso - Agora move para 'Para Verificar' para que o usuário possa interagir
      autodetection.update!(status: 'to_verify', error_message: nil)
    rescue => e
      # Em caso de qualquer pane, salva o erro para visualização do usuário na tela e permite tentar novamente
      Rails.logger.error "AutodetectJob Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      autodetection.update!(status: 'error', error_message: e.message)
    end
  end
end

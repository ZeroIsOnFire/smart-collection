# frozen_string_literal: true

class AutodetectJob < ApplicationJob
  queue_as :default

  def perform(autodetection_id)
    autodetection = Autodetection.find(autodetection_id)
    return unless autodetection

    # Atualiza o status para processing, que fará trigger no Turbo Stream
    autodetection.update!(status: 'processing')

    begin
      prepared_photo_path = prepare_photo_for_detection(autodetection)

      # 1. Analisar a imagem usando YOLO local
      detected_items_data = []

      if YoloDetectionService.service_configured?
        Rails.logger.info "AutodetectJob: Attempting YOLO detection for autodetection #{autodetection_id}"
        detected_items_data = YoloDetectionService.analyze(prepared_photo_path)
      end

      Rails.logger.info "AutodetectJob: No items found for autodetection #{autodetection_id}" if detected_items_data.empty?

      # 2. Processar cada item detectado
      detected_items_data.each do |data|
        # Recortar a imagem baseado nas coordenadas retornadas
        cropped_file = ImageCropperService.crop(
          autodetection.photo.path,
          data[:vertices],
          minimum_side: ImageCropperService.default_minimum_side,
          upscale: upscale_options(autodetection)
        )

        next unless cropped_file

        autodetection.detected_items.create!(
          label: I18n.t('autodetections.detected_item.new_item'),
          color: data[:color],
          skip_upscaler: autodetection.skip_upscaler?,
          cropped_photo_upscale_strategy: detected_item_upscale_strategy(autodetection, cropped_file),
          position_data: {
            vertices: data[:vertices],
            score: data[:score]
          },
          cropped_photo: cropped_file
        )
        UsageMetric.record!('yolo_detected_items')
        track_upscaled_photo(cropped_file)
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

  private

  def prepare_photo_for_detection(autodetection)
    return autodetection.photo.path unless upscaling_enabled?(autodetection)

    upscaled_file = ImageUpscalerService.upscale_if_needed(
      autodetection.photo.path,
      minimum_side: AutodetectionService.autodetection_minimum_side,
      use_ai: true,
      local_fallback: true
    )

    return autodetection.photo.path unless upscaled_file

    track_upscaled_photo(upscaled_file)
    autodetection.photo = upscaled_file
    autodetection.photo_upscale_strategy = upscale_strategy(upscaled_file)
    autodetection.save!
    autodetection.photo.path
  ensure
    cleanup_tempfile(upscaled_file)
  end

  def upscale_options(autodetection)
    enabled = upscaling_enabled?(autodetection)

    { use_ai: enabled, local_fallback: enabled }
  end

  def upscaling_enabled?(autodetection)
    autodetection.user.ai_upscaling_enabled? && !autodetection.skip_upscaler?
  end

  def cleanup_tempfile(tempfile)
    return unless tempfile.respond_to?(:close)

    tempfile.close
    tempfile.unlink
  rescue StandardError
    nil
  end

  def track_upscaled_photo(file)
    return unless file.respond_to?(:upscale_strategy)

    UsageMetric.record!("photos_upscaled_#{file.upscale_strategy}")
  end

  def upscale_strategy(file)
    return unless file.respond_to?(:upscale_strategy)

    file.upscale_strategy.to_s
  end

  def detected_item_upscale_strategy(autodetection, file)
    upscale_strategy(file).presence || autodetection.photo_upscale_strategy
  end
end

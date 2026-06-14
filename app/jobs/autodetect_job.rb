# frozen_string_literal: true

class AutodetectJob < ApplicationJob
  queue_as :default

  def perform(autodetection_id)
    autodetection = Autodetection.find(autodetection_id)
    return unless autodetection

    # Atualiza o status para processing, que fará trigger no Turbo Stream
    autodetection.update!(status: 'processing')

    begin
      preserve_original_photo(autodetection)
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
        original_cropped_file = original_cropped_file_for(autodetection, data, cropped_file)

        next unless cropped_file || original_cropped_file

        autodetection.detected_items.create!(
          label: I18n.t('autodetections.detected_item.new_item'),
          color: data[:color],
          skip_upscaler: autodetection.skip_upscaler?,
          cropped_photo_upscale_strategy: detected_item_upscale_strategy(autodetection, cropped_file),
          cropped_photo_variant: detected_item_photo_variant(autodetection, cropped_file),
          position_data: {
            vertices: data[:vertices],
            score: data[:score]
          },
          cropped_photo: display_cropped_file(autodetection, cropped_file, original_cropped_file),
          original_cropped_photo: original_cropped_file,
          enhanced_cropped_photo: enhanced_cropped_file(autodetection, cropped_file)
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

  def preserve_original_photo(autodetection)
    return if autodetection.original_photo? || autodetection.photo.blank?

    File.open(autodetection.photo.path) do |photo_file|
      autodetection.original_photo = photo_file
      autodetection.original_photo.store!
      autodetection.write_attribute(:original_photo_filename, autodetection.original_photo.identifier)
    end
    autodetection.save!
  end

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
    strategy = upscale_strategy(upscaled_file)
    store_enhanced_photo(autodetection, upscaled_file) if strategy == 'ai'
    autodetection.photo = upscaled_file
    autodetection.photo_upscale_strategy = strategy
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

  def detected_item_photo_variant(autodetection, file)
    detected_item_upscale_strategy(autodetection, file) == 'ai' ? 'ai' : 'original'
  end

  def display_cropped_file(autodetection, cropped_file, original_cropped_file)
    return cropped_file if detected_item_photo_variant(autodetection, cropped_file) == 'ai'

    original_cropped_file || cropped_file
  end

  def enhanced_cropped_file(autodetection, cropped_file)
    cropped_file if detected_item_photo_variant(autodetection, cropped_file) == 'ai'
  end

  def original_photo_path_for(autodetection)
    autodetection.original_photo? ? autodetection.original_photo.path : autodetection.photo.path
  end

  def original_cropped_file_for(autodetection, data, cropped_file)
    return unless detected_item_photo_variant(autodetection, cropped_file) == 'ai'

    # TODO: verificar se o original do autodetect funciona corretamente em todos os cenarios.
    ImageCropperService.crop(
      original_photo_path_for(autodetection),
      data[:vertices],
      minimum_side: ImageCropperService.default_minimum_side,
      upscale: { use_ai: false, local_fallback: false }
    )
  end

  def store_enhanced_photo(autodetection, file)
    File.open(file.path) do |photo_file|
      autodetection.enhanced_photo = photo_file
      autodetection.enhanced_photo.store!
      autodetection.write_attribute(:enhanced_photo_filename, autodetection.enhanced_photo.identifier)
    end
  end
end

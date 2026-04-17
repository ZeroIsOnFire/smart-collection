class DetectedItemService
  def undo(detected_item, current_user)
    # 1. Se o item estava salvo, busca e remove o carro proporcionalmente
    if detected_item.status == 'saved' && detected_item.car_id.present?
      # Usa where.first para evitar a exceção DocumentNotFound se o carro já tiver sido removido
      car = Car.where(id: detected_item.car_id, user_id: current_user.id).first
      car.destroy if car
    end

    # 2. Reseta o status do item
    detected_item.update(status: 'pending', car_id: nil)

    # 3. Atualiza o status da autodetection se necessário
    # Se a autodetection estava 'completed', volta para 'processing' pois agora há um item pendente
    autodetection = detected_item.autodetection
    if autodetection.status == 'completed'
      autodetection.update(status: 'to_verify')
    end

    true
  rescue StandardError => e
    Rails.logger.error "Error undoing detected item #{detected_item.id}: #{e.message}"
    false
  end
end

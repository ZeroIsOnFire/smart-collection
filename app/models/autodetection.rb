class Autodetection
  include Mongoid::Document
  include Mongoid::Timestamps
  include CarrierWave::Mongoid

  field :status, type: String, default: 'pending'
  field :error_message, type: String

  mount_uploader :photo, PhotoUploader

  belongs_to :user
  has_many :detected_items, dependent: :destroy

  validates :photo, presence: true

  # Constants for status
  STATUSES = %w[pending processing to_verify completed error].freeze
  validates :status, inclusion: { in: STATUSES }

  # Verifica se todos os itens foram processados e conclui a autodetecção
  def check_completion!
    # Se já estiver em erro ou já concluído, não faz nada
    return if %w[error completed].include?(status)

    # Se todos os itens estão 'saved' ou 'rejected', conclui a tarefa
    if detected_items.any? && detected_items.all? { |item| %w[saved rejected].include?(item.status) }
      update(status: 'completed')
    end
  end

  # Callbacks de broadcast em tempo real
  after_create :broadcast_new_autodetection
  after_update :broadcast_update_autodetection

  private

  def broadcast_new_autodetection
    Turbo::StreamsChannel.broadcast_prepend_to(
      "autodetections_#{user_id.to_s}",
      target: "autodetections_list",
      partial: "autodetections/autodetection",
      locals: { autodetection: self }
    )
  end

  def broadcast_update_autodetection
    if status == 'completed'
      Turbo::StreamsChannel.broadcast_remove_to(
        "autodetections_#{user_id.to_s}",
        target: "autodetection_#{id.to_s}"
      )
    else
      Turbo::StreamsChannel.broadcast_replace_to(
        "autodetections_#{user_id.to_s}",
        target: "autodetection_#{id.to_s}",
        partial: "autodetections/autodetection",
        locals: { autodetection: self }
      )
    end
  end

end

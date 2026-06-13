# frozen_string_literal: true

class Autodetection
  include Mongoid::Document
  include Mongoid::Timestamps
  include CarrierWave::Mongoid

  field :status, type: String, default: 'pending'
  field :error_message, type: String
  field :skip_upscaler, type: Boolean, default: false

  mount_uploader :photo, PhotoUploader

  belongs_to :user
  has_many :detected_items, dependent: :destroy

  index({ status: 1, updated_at: 1 })
  index({ user_id: 1, created_at: -1 })

  scope :active, -> { where(:status.ne => 'completed') }
  scope :active_recent, -> { active.desc(:created_at) }

  validates :photo, presence: true

  # Constants for status
  STATUSES = %w[pending processing to_verify completed error].freeze
  validates :status, inclusion: { in: STATUSES }

  # Verifica se todos os itens foram processados e conclui a autodetecção
  def check_completion!
    # Se já estiver em erro ou já concluído, não faz nada
    return if %w[error completed].include?(status)

    # Se todos os itens estão 'saved' ou 'rejected', conclui a tarefa
    return unless detected_items.any? && detected_items.all? { |item| %w[saved rejected].include?(item.status) }

    update(status: 'completed')
  end

  def self.cleanup_old_records(older_than: 24.hours.ago)
    # Deleta autodetecções concluídas ou com erro há mais de X tempo
    # destroy_all é necessário para disparar os callbacks do CarrierWave e deletar os arquivos
    where(:status.in => %w[completed error], :updated_at.lt => older_than).destroy_all
  end

  # Callbacks de broadcast em tempo real
  after_create :broadcast_new_autodetection
  after_update :broadcast_update_autodetection

  private

  def broadcast_new_autodetection
    Turbo::StreamsChannel.broadcast_prepend_to(
      "autodetections_#{user_id}",
      target: 'autodetections_list',
      partial: 'autodetections/autodetection',
      locals: { autodetection: self }
    )
  end

  def broadcast_update_autodetection
    if status == 'completed'
      Turbo::StreamsChannel.broadcast_remove_to(
        "autodetections_#{user_id}",
        target: "autodetection_#{id}"
      )
    else
      Turbo::StreamsChannel.broadcast_replace_to(
        "autodetections_#{user_id}",
        target: "autodetection_#{id}",
        partial: 'autodetections/autodetection',
        locals: { autodetection: self }
      )
    end
  end
end

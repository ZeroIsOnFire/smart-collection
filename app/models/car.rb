# frozen_string_literal: true

class Car
  include Mongoid::Document
  include Mongoid::Timestamps
  include CarrierWave::Mongoid

  field :name, type: String
  field :brand, type: String
  field :manufacturer, type: String
  field :observations, type: String
  field :size, type: String
  field :year, type: Integer
  field :color, type: String
  field :tags, type: Array, default: []
  field :detected_via_ai, type: Boolean, default: false

  COLORS = {
    'Branco' => '#FFFFFF',
    'Preto' => '#000000',
    'Prata' => '#C0C0C0',
    'Cinza' => '#808080',
    'Vermelho' => '#FF0000',
    'Azul' => '#0000FF',
    'Amarelo' => '#FFFF00',
    'Verde' => '#008000',
    'Laranja' => '#FFA500',
    'Roxo' => '#800080',
    'Rosa' => '#FFC0CB',
    'Marrom' => '#A52A2A',
    'Dourado' => '#FFD700',
    'Bege' => '#F5F5DC'
  }.freeze

  SCALES = [
    '1:12', '1:18', '1:24', '1:32', '1:36', '1:43', '1:48',
    '1:50', '1:55', '1:60', '1:64', '1:72', '1:76', '1:87',
    '1:100', '1:120', '1:144', '1:160', 'Outra'
  ].freeze

  def self.color_options
    COLORS.keys.map { |name| [name, name] }
  end

  def self.scale_options
    SCALES.map { |s| [s, s] }
  end

  mount_uploader :photo, PhotoUploader

  index({
          name: 'text',
          brand: 'text',
          manufacturer: 'text',
          observations: 'text',
          size: 'text',
          tags: 'text'
        }, {
          weights: {
            name: 10,
            brand: 5,
            manufacturer: 2,
            observations: 1,
            size: 1,
            tags: 1
          },
          name: 'CarTextIndex'
        })
  index({ user_id: 1, created_at: -1 })
  index({ user_id: 1, name: 1 })
  index({ detected_via_ai: 1 }, { background: true })

  belongs_to :user, touch: true

  # Assume standard ActiveStorage with mongoid wrapper setup later or skip if unsupported natively without gem.
  # For now just basic fields to fulfill the crud.
  # include Mongoid::ActiveStorage if configured.

  validates :name, presence: true
end

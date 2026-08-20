# frozen_string_literal: true

class Car
  include Mongoid::Document
  include Mongoid::Timestamps
  include CarrierWave::Mongoid

  field :name, type: String
  field :brand, type: String
  field :observations, type: String
  field :size, type: String
  field :year, type: Integer
  field :color, type: String
  field :tags, type: Array, default: []
  field :detected_via_ai, type: Boolean, default: false
  field :skip_upscaler, type: Boolean, default: false
  field :photo_upscale_strategy, type: String
  field :photo_variant, type: String

  # Atributo para persistência do CarrierWave entre falhas de validação
  field :photo_cache, type: String
  field :photo_processing_status, type: String
  field :photo_processing_error, type: String
  field :photo_processing_crop_x, type: Float
  field :photo_processing_crop_y, type: Float
  field :photo_processing_crop_w, type: Float
  field :photo_processing_crop_h, type: Float
  field :photo_crop_x, type: Float
  field :photo_crop_y, type: Float
  field :photo_crop_w, type: Float
  field :photo_crop_h, type: Float

  # Virtual attributes for image cropping
  attr_writer :crop_x, :crop_y, :crop_w, :crop_h

  PHOTO_PROCESSING_STATUSES = %w[pending processing completed error].freeze

  COLORS = {
    'white' => '#FFFFFF',
    'black' => '#000000',
    'silver' => '#C0C0C0',
    'gray' => '#808080',
    'red' => '#FF0000',
    'blue' => '#0000FF',
    'yellow' => '#FFFF00',
    'green' => '#008000',
    'orange' => '#FFA500',
    'purple' => '#800080',
    'pink' => '#FFC0CB',
    'brown' => '#A52A2A',
    'gold' => '#FFD700',
    'beige' => '#F5F5DC'
  }.freeze

  LEGACY_COLOR_KEYS = {
    'Branco' => 'white',
    'Preto' => 'black',
    'Prata' => 'silver',
    'Cinza' => 'gray',
    'Vermelho' => 'red',
    'Azul' => 'blue',
    'Amarelo' => 'yellow',
    'Verde' => 'green',
    'Laranja' => 'orange',
    'Roxo' => 'purple',
    'Rosa' => 'pink',
    'Marrom' => 'brown',
    'Dourado' => 'gold',
    'Bege' => 'beige'
  }.freeze

  SCALES = [
    '1:12', '1:18', '1:24', '1:32', '1:36', '1:43', '1:48',
    '1:50', '1:55', '1:60', '1:64', '1:72', '1:76', '1:87',
    '1:100', '1:120', '1:144', '1:160', 'Outra'
  ].freeze

  def self.color_options
    COLORS.keys.map { |name| [I18n.t("colors.#{name}", default: name), name] }
  end

  def self.scale_options
    SCALES.map do |s|
      label = s == 'Outra' ? I18n.t('scales.other', default: s) : s
      [label, s]
    end
  end

  mount_uploader :photo, PhotoUploader
  mount_uploader :original_photo, PhotoUploader
  mount_uploader :enhanced_photo, PhotoUploader

  index({
          name: 'text',
          brand: 'text',
          observations: 'text',
          size: 'text',
          tags: 'text'
        }, {
          weights: {
            name: 10,
            brand: 5,
            observations: 1,
            size: 1,
            tags: 1
          },
          name: 'CarTextIndex'
        })
  index({ user_id: 1, created_at: -1 })
  index({ user_id: 1, name: 1 })
  index({ user_id: 1, photo_processing_status: 1 }, { background: true })
  index({ detected_via_ai: 1 }, { background: true })

  belongs_to :user, touch: true
  after_create :track_creation
  after_update :clear_share_image_cache
  after_destroy :clear_share_image_cache
  after_destroy :track_removal

  # Assume standard ActiveStorage with mongoid wrapper setup later or skip if unsupported natively without gem.
  # For now just basic fields to fulfill the crud.
  # include Mongoid::ActiveStorage if configured.

  validates :name, presence: true
  validates :photo_processing_status, inclusion: { in: PHOTO_PROCESSING_STATUSES }, allow_blank: true
  validates :photo_variant, inclusion: { in: %w[original ai] }, allow_blank: true
  validate :year_must_be_numeric

  def photo_processing?
    photo_processing_status.in?(%w[pending processing])
  end

  def photo_processing_crop?
    photo_processing? &&
      [photo_processing_crop_x, photo_processing_crop_y, photo_processing_crop_w, photo_processing_crop_h].all?(&:present?) &&
      photo_processing_crop_w.positive? &&
      photo_processing_crop_h.positive?
  end

  def photo_upscaled_by_ai?
    if original_photo? || enhanced_photo?
      photo_variant == 'ai' && enhanced_photo?
    else
      photo_upscale_strategy == 'ai'
    end
  end

  def original_photo_available?
    original_photo?
  end

  def enhanced_photo_available?
    enhanced_photo?
  end

  def selectable_photo_variant?
    original_photo_available? && enhanced_photo_available?
  end

  def crop_x
    defined?(@crop_x) && !@crop_x.nil? ? @crop_x : photo_crop_x
  end

  def crop_y
    defined?(@crop_y) && !@crop_y.nil? ? @crop_y : photo_crop_y
  end

  def crop_w
    defined?(@crop_w) && !@crop_w.nil? ? @crop_w : photo_crop_w
  end

  def crop_h
    defined?(@crop_h) && !@crop_h.nil? ? @crop_h : photo_crop_h
  end

  private

  def track_creation
    UsageMetric.record!('cars_created')
  end

  def track_removal
    UsageMetric.record!('cars_removed')
  end

  def clear_share_image_cache
    ShareImageCacheService.clear(record: self, kind: :car)
  end

  def year_must_be_numeric
    raw_year = year_before_type_cast
    return if raw_year.blank? || raw_year.to_s.match?(/\A\d+\z/)

    errors.add(:year, :not_a_number)
  end
end

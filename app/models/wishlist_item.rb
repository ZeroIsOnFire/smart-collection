# frozen_string_literal: true

class WishlistItem
  include Mongoid::Document
  include Mongoid::Timestamps
  include CarrierWave::Mongoid

  STATUSES = %w[wanted reserved purchased].freeze
  PRIORITIES = %w[low medium high dream].freeze

  field :name, type: String
  field :brand, type: String
  field :scale, type: String
  field :observations, type: String
  field :priority, type: String, default: 'medium'
  field :status, type: String, default: 'wanted'
  field :target_price_cents, type: Integer
  field :reference_url, type: String
  field :photo_cache, type: String

  mount_uploader :photo, PhotoUploader

  belongs_to :user
  belongs_to :car, optional: true

  index({ user_id: 1 }, { background: true })
  index({ user_id: 1, status: 1 }, { background: true })
  index({ user_id: 1, priority: 1 }, { background: true })
  index({ user_id: 1, brand: 1 }, { background: true })
  index({ user_id: 1, created_at: -1 }, { background: true })

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :target_price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validate :reference_url_must_be_http

  before_validation :normalize_reference_url

  def self.status_options
    STATUSES.map { |value| [I18n.t("wishlist_items.statuses.#{value}"), value] }
  end

  def self.priority_options
    PRIORITIES.map { |value| [I18n.t("wishlist_items.priorities.#{value}"), value] }
  end

  def status_label
    I18n.t("wishlist_items.statuses.#{status}")
  end

  def priority_label
    I18n.t("wishlist_items.priorities.#{priority}")
  end

  def target_price
    return nil if target_price_cents.blank?

    target_price_cents / 100.0
  end

  private

  def normalize_reference_url
    self.reference_url = reference_url.to_s.strip.presence
  end

  def reference_url_must_be_http
    return if reference_url.blank?

    uri = URI.parse(reference_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present?

    errors.add(:reference_url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:reference_url, :invalid)
  end
end

# frozen_string_literal: true

class DetectedItem
  include Mongoid::Document
  include Mongoid::Timestamps
  include CarrierWave::Mongoid

  field :label, type: String
  field :status, type: String, default: 'pending'
  field :car_id, type: BSON::ObjectId
  field :position_data, type: Hash
  field :color, type: String
  field :year, type: Integer
  field :size, type: String
  field :brand, type: String
  field :skip_upscaler, type: Boolean, default: false
  field :cropped_photo_upscale_strategy, type: String
  field :image_processing_status, type: String
  field :image_processing_error, type: String

  mount_uploader :cropped_photo, CroppedPhotoUploader

  belongs_to :autodetection
  index({ autodetection_id: 1 }, { background: true })

  STATUSES = %w[pending saved rejected].freeze
  IMAGE_PROCESSING_STATUSES = %w[pending processing completed error].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :image_processing_status, inclusion: { in: IMAGE_PROCESSING_STATUSES }, allow_blank: true
  validates :label, presence: true

  # Real-time broadcast to the autodetection page
  after_create_commit :broadcast_new_item
  after_destroy_commit :broadcast_remove_item
  after_destroy :track_removal

  def image_processing?
    image_processing_status.in?(%w[pending processing])
  end

  private

  def track_removal
    UsageMetric.record!('detected_items_removed')
  end

  def broadcast_new_item
    Turbo::StreamsChannel.broadcast_append_to(
      "autodetection_#{autodetection_id}_items",
      target: "detected_items_list_#{autodetection_id}",
      partial: 'detected_items/detected_item',
      locals: { detected_item: self }
    )
  end

  def broadcast_remove_item
    Turbo::StreamsChannel.broadcast_remove_to(
      "autodetection_#{autodetection_id}_items",
      target: "detected_item_#{id}"
    )
  end
end

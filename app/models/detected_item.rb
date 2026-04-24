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

  mount_uploader :cropped_photo, CroppedPhotoUploader

  belongs_to :autodetection

  STATUSES = %w[pending saved rejected].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :label, presence: true

  # Real-time broadcast to the autodetection page
  after_create_commit :broadcast_new_item
  after_destroy_commit :broadcast_remove_item

  private

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

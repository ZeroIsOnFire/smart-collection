# frozen_string_literal: true

class CollectionExport
  include Mongoid::Document
  include Mongoid::Timestamps
  include CarrierWave::Mongoid

  field :status, type: String, default: 'pending' # pending, processing, completed, failed
  field :format_type, type: String, default: 'csv'
  field :export_type, type: String, default: 'collection'
  field :file, type: String
  field :file_filename, type: String
  field :error_message, type: String

  belongs_to :user

  mount_uploader :file, ExportFileUploader

  validates :status, inclusion: { in: %w[pending processing completed failed] }
  validates :format_type, inclusion: { in: %w[csv pdf] }
  validates :export_type, inclusion: { in: %w[collection wishlist] }

  after_save :broadcast_status_update
  after_destroy_commit :broadcast_removal

  private

  def broadcast_status_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user_id}_exports",
      target: status_container_id,
      partial: 'collection_exports/export_status',
      locals: { export: self, format_type: format_type, export_type: export_type }
    )
  end

  def broadcast_removal
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user_id}_exports",
      target: status_container_id,
      partial: 'collection_exports/export_status',
      locals: { export: nil, format_type: format_type, export_type: export_type }
    )
  end

  def status_container_id
    export_type == 'wishlist' ? "wishlist_export_#{format_type}_status_container" : "export_#{format_type}_status_container"
  end
end

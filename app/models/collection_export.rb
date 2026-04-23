class CollectionExport
  include Mongoid::Document
  include Mongoid::Timestamps
  include CarrierWave::Mongoid

  field :status, type: String, default: 'pending' # pending, processing, completed, failed
  field :format_type, type: String, default: 'csv'
  field :error_message, type: String

  belongs_to :user

  mount_uploader :file, ExportFileUploader

  validates :status, inclusion: { in: %w[pending processing completed failed] }
  validates :format_type, inclusion: { in: %w[csv pdf] }

  after_save :broadcast_status_update
  after_destroy_commit :broadcast_removal

  private

  def broadcast_status_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user_id.to_s}_exports",
      target: "export_#{format_type}_status_container",
      partial: "collection_exports/export_status",
      locals: { export: self, format_type: format_type }
    )
  end

  def broadcast_removal
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user_id.to_s}_exports",
      target: "export_#{format_type}_status_container",
      partial: "collection_exports/export_status",
      locals: { export: nil, format_type: format_type }
    )
  end
end

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

  private

  def broadcast_status_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user_id}_exports",
      target: "export_status_container",
      partial: "collection_exports/export_status",
      locals: { export: self }
    )
  end
end

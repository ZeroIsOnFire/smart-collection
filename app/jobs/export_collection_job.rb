# frozen_string_literal: true

class ExportCollectionJob < ApplicationJob
  queue_as :default

  def perform(export_id)
    export = CollectionExport.find(export_id)
    return unless export

    export.update(status: 'processing')

    begin
      generated_at = Time.current

      if export.format_type == 'csv'
        data = csv_data_for(export)

        temp_file = Tempfile.new(["export_#{export.id}", '.csv'])
        temp_file.write("\xEF\xBB\xBF") # BOM para UTF-8 no Excel
      else
        data = pdf_data_for(export, generated_at)

        temp_file = Tempfile.new(["export_#{export.id}", '.pdf'])
        temp_file.binmode
      end
      temp_file.write(data)
      temp_file.rewind

      export.file = ActionDispatch::Http::UploadedFile.new(
        tempfile: temp_file,
        filename: export_filename(export),
        type: export.format_type == 'csv' ? 'text/csv' : 'application/pdf'
      )
      export.status = 'completed'
      export.save!
      sync_export_identifier(export)
    rescue StandardError => e
      export.update(status: 'failed', error_message: e.message)
    ensure
      temp_file&.close
      temp_file&.unlink
    end
  end

  private

  def csv_data_for(export)
    if export.export_type == 'wishlist'
      WishlistCsvExportService.new(export.user.wishlist_items.asc(:created_at)).generate
    else
      ExportCsvService.new(export.user.cars.order(created_at: :asc)).generate
    end
  end

  def pdf_data_for(export, generated_at)
    if export.export_type == 'wishlist'
      WishlistPdfExportService.new(
        export.user,
        export.user.wishlist_items.asc(:created_at),
        generated_at: generated_at
      ).generate
    else
      ExportPdfService.new(
        export.user,
        export.user.cars.order(created_at: :asc),
        generated_at: generated_at
      ).generate
    end
  end

  def export_filename(export)
    prefix = export.export_type == 'wishlist' ? 'wishlist' : 'collection'
    "#{prefix}-#{Time.current.strftime('%Y%m%d-%H%M')}.#{export.format_type}"
  end

  def sync_export_identifier(export)
    return if export[:file].present? || export[:file_filename].blank?

    CollectionExport.collection.find(_id: export.id).update_one('$set' => { 'file' => export[:file_filename] })
  end
end

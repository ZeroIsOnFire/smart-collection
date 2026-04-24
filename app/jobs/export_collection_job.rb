# frozen_string_literal: true

class ExportCollectionJob < ApplicationJob
  queue_as :default

  def perform(export_id)
    export = CollectionExport.find(export_id)
    return unless export

    export.update(status: 'processing')

    begin
      if export.format_type == 'csv'
        data = ExportCsvService.new(export.user.cars.order(created_at: :asc)).generate

        temp_file = Tempfile.new(["export_#{export.id}", '.csv'])
        temp_file.write("\xEF\xBB\xBF") # BOM para UTF-8 no Excel
      else
        data = ExportPdfService.new(export.user, export.user.cars.order(created_at: :asc)).generate

        temp_file = Tempfile.new(["export_#{export.id}", '.pdf'])
        temp_file.binmode
      end
      temp_file.write(data)
      temp_file.rewind

      export.file = temp_file
      export.status = 'completed'
      export.save!
    rescue StandardError => e
      export.update(status: 'failed', error_message: e.message)
    ensure
      temp_file&.close
      temp_file&.unlink
    end
  end
end

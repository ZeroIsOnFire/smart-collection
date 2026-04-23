class ExportCollectionJob < ApplicationJob
  queue_as :default

  def perform(export_id)
    export = CollectionExport.find(export_id)
    return unless export

    export.update(status: 'processing')

    begin
      csv_data = ExportCsvService.new(export.user.cars.order(created_at: :asc)).generate
      
      temp_file = Tempfile.new(["export_#{export.id}", ".csv"])
      # Escrevendo com encoding que funciona bem no excel também:
      temp_file.write("\xEF\xBB\xBF") # BOM para UTF-8 no Excel
      temp_file.write(csv_data)
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

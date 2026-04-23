class CollectionExportsController < ApplicationController
  before_action :authenticate_user!

  def create
    @export = current_user.collection_exports.create!(status: 'pending', format_type: 'csv')
    ExportCollectionJob.perform_later(@export.id.to_s)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "export_status_container",
          partial: "collection_exports/export_status",
          locals: { export: @export }
        )
      end
      format.html { redirect_to cars_path, notice: 'Exportação iniciada.' }
    end
  end

  def destroy
    @export = current_user.collection_exports.find(params[:id])
    @export.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "export_status_container",
          partial: "collection_exports/export_status",
          locals: { export: nil }
        )
      end
      format.html { redirect_to cars_path, notice: 'Exportação removida.' }
    end
  end
end

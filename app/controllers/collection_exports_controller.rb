class CollectionExportsController < ApplicationController
  before_action :authenticate_user!

  def create
    format_type = params[:format_type] || 'csv'
    current_user.collection_exports.where(format_type: format_type).destroy_all

    @export = current_user.collection_exports.create!(status: 'pending', format_type: format_type)
    ExportCollectionJob.perform_later(@export.id.to_s)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "export_#{format_type}_status_container",
          partial: "collection_exports/export_status",
          locals: { export: @export, format_type: format_type }
        )
      end
      format.html { redirect_to cars_path, notice: 'Exportação iniciada.' }
    end
  end

  def destroy
    @export = current_user.collection_exports.find(params[:id])
    format_type = @export.format_type
    @export.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "export_#{format_type}_status_container",
          partial: "collection_exports/export_status",
          locals: { export: nil, format_type: format_type }
        )
      end
      format.html { redirect_to cars_path, notice: 'Exportação removida.' }
    end
  end
end

# frozen_string_literal: true

class CollectionExportsController < ApplicationController
  before_action :authenticate_user!

  def create
    format_type = params[:format_type] || 'csv'
    export_type = export_type_param
    current_user.collection_exports.where(format_type: format_type, export_type: export_type).destroy_all

    @export = current_user.collection_exports.create!(status: 'pending', format_type: format_type, export_type: export_type)
    ExportCollectionJob.perform_later(@export.id.to_s)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          status_container_id(format_type, export_type),
          partial: 'collection_exports/export_status',
          locals: { export: @export, format_type: format_type, export_type: export_type }
        )
      end
      format.html { redirect_to redirect_path_for(export_type), notice: t('collection_exports.messages.started') }
    end
  end

  def destroy
    @export = current_user.collection_exports.find(params[:id])
    format_type = @export.format_type
    export_type = @export.export_type
    @export.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          status_container_id(format_type, export_type),
          partial: 'collection_exports/export_status',
          locals: { export: nil, format_type: format_type, export_type: export_type }
        )
      end
      format.html { redirect_to redirect_path_for(export_type), notice: t('collection_exports.messages.removed') }
    end
  end

  def status
    format_type = params[:format_type] || 'csv'
    export_type = export_type_param
    @export = current_user.collection_exports.where(format_type: format_type, export_type: export_type).last

    render partial: 'collection_exports/export_status',
           locals: { export: @export, format_type: format_type, export_type: export_type }
  end

  private

  def export_type_param
    params[:export_type] == 'wishlist' ? 'wishlist' : 'collection'
  end

  def status_container_id(format_type, export_type)
    export_type == 'wishlist' ? "wishlist_export_#{format_type}_status_container" : "export_#{format_type}_status_container"
  end

  def redirect_path_for(export_type)
    export_type == 'wishlist' ? wishlist_items_path : cars_path
  end
end

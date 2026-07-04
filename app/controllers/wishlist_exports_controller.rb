# frozen_string_literal: true

class WishlistExportsController < ApplicationController
  before_action :authenticate_user!

  def show
    wishlist_items = current_user.wishlist_items.asc(:created_at)

    respond_to do |format|
      format.csv do
        send_data WishlistCsvExportService.new(wishlist_items).generate,
                  filename: export_filename('csv'),
                  type: 'text/csv; charset=utf-8'
      end
      format.pdf do
        send_data WishlistPdfExportService.new(current_user, wishlist_items).generate,
                  filename: export_filename('pdf'),
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
      format.html { redirect_to wishlist_items_path }
    end
  end

  private

  def export_filename(extension)
    "wishlist-#{Time.current.strftime('%Y%m%d-%H%M')}.#{extension}"
  end
end

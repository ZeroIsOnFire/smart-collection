# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WishlistExports', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /wishlist/export.csv' do
    it 'exports only current user wishlist items' do
      create(:wishlist_item, user: user, name: 'Visible wish')
      create(:wishlist_item, user: other_user, name: 'Private wish')

      get wishlist_export_path(format: :csv)

      expect(response).to be_successful
      expect(response.media_type).to eq('text/csv')
      expect(response.body).to include('Visible wish')
      expect(response.body).not_to include('Private wish')
    end
  end

  describe 'GET /wishlist/export.pdf' do
    it 'exports a PDF for the current user wishlist' do
      create(:wishlist_item, user: user)

      get wishlist_export_path(format: :pdf)

      expect(response).to be_successful
      expect(response.media_type).to eq('application/pdf')
      expect(response.body).to start_with('%PDF')
    end
  end
end

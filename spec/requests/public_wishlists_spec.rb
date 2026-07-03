# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PublicWishlists', type: :request do
  let(:user) do
    create(:user, wishlist_sharing_enabled: true, wishlist_share_token: 'wishlist-token',
                  wishlist_public_show_status: true, wishlist_public_show_priority: true)
  end

  describe 'GET /wishlist/public/:token' do
    it 'allows access without login and renders shared wishlist items' do
      user.update!(sharing_enabled: true, share_token: 'collection-token')
      create(:wishlist_item, user: user, name: 'Public wish', reference_url: 'https://example.com/private-trace')

      get public_wishlist_path(user.wishlist_share_token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t('public_wishlists.show.title', name: user.name))
      expect(response.body).to include('Public wish')
      expect(response.body).not_to include('private-trace')
      expect(response.body).to include('public_wishlist_view_preference')
      expect(response.body).to include('view-toggle#setList')
      expect(response.body).to include(public_share_url(user.share_token))
      expect(response.body).to include('data-turbo-frame="modal"')
      expect(response.body).not_to include('target="_blank"')
      expect(response.body).to include('data-controller="search-form"')
      expect(response.body).to include('data-turbo-frame="public_wishlist_grid"')
      expect(response.body).to include(I18n.t('wishlist_items.index.filter_menu'))
    end

    it 'filters public wishlist by query, status, priority, brand and scale without searching notes' do
      create(:wishlist_item, user: user, name: 'Matching wish', brand: 'Mini GT',
                             scale: '1:64', status: 'reserved', priority: 'dream')
      create(:wishlist_item, user: user, name: 'Other wish', brand: 'Hot Wheels',
                             scale: '1:18', status: 'wanted', priority: 'low')
      create(:wishlist_item, user: user, name: 'Notes only wish', brand: 'Mini GT',
                             scale: '1:64', status: 'reserved', priority: 'dream',
                             observations: 'Matching')

      get public_wishlist_path(user.wishlist_share_token),
          params: { q: 'Matching', status: 'reserved', priority: 'dream', brand: 'Mini GT', scale: '1:64' }

      expect(response.body).to include('Matching wish')
      expect(response.body).not_to include('Other wish')
      expect(response.body).not_to include('Notes only wish')
      expect(response.body).to include('1 resultado para')
      expect(response.body).to include('Matching')
    end

    it 'hides purchased public wishlist items by default' do
      create(:wishlist_item, user: user, name: 'Public wanted', status: 'wanted')
      create(:wishlist_item, user: user, name: 'Public acquired', status: 'purchased')

      get public_wishlist_path(user.wishlist_share_token)

      expect(response.body).to include('Public wanted')
      expect(response.body).not_to include('Public acquired')
      expect(response.body).to include(I18n.t('wishlist_items.filters.without_purchased'))

      get public_wishlist_path(user.wishlist_share_token), params: { status: '' }

      expect(response.body).to include('Public wanted')
      expect(response.body).to include('Public acquired')
    end

    it 'does not expose the wishlist when sharing is disabled' do
      user.update!(wishlist_sharing_enabled: false)

      get public_wishlist_path(user.wishlist_share_token)

      expect(response).to have_http_status(:not_found)
    end

    it 'does not expose another private wishlist through a valid token' do
      private_user = create(:user, wishlist_sharing_enabled: false, wishlist_share_token: 'private-token')
      create(:wishlist_item, user: private_user, name: 'Hidden wish')

      get public_wishlist_path(private_user.wishlist_share_token)

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Hidden wish')
    end
  end

  describe 'GET /wishlist/public/:token/items/:id' do
    it 'renders public wishlist item details in a modal with share image action' do
      item = create(:wishlist_item, user: user, name: 'Modal public wish', brand: 'Mini GT', scale: '1:64')

      get public_wishlist_item_path(user.wishlist_share_token, item), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('turboModal')
      expect(response.body).to include('Modal public wish')
      expect(response.body).to include(public_wishlist_item_share_image_path(user.wishlist_share_token, item))
      expect(response.body).to include(I18n.t('wishlist_items.actions.share_item_image'))
    end

    it 'does not expose public details when sharing is disabled' do
      item = create(:wishlist_item, user: user)
      user.update!(wishlist_sharing_enabled: false)

      get public_wishlist_item_path(user.wishlist_share_token, item), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to have_http_status(:not_found)
    end
  end
end

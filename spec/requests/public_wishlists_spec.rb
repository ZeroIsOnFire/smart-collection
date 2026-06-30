# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PublicWishlists', type: :request do
  let(:user) do
    create(:user, wishlist_sharing_enabled: true, wishlist_share_token: 'wishlist-token',
                  wishlist_public_show_status: true, wishlist_public_show_priority: true)
  end

  describe 'GET /wishlist/public/:token' do
    it 'allows access without login and renders shared wishlist items' do
      create(:wishlist_item, user: user, name: 'Public wish', reference_url: 'https://example.com/private-trace')

      get public_wishlist_path(user.wishlist_share_token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t('public_wishlists.show.title', name: user.name))
      expect(response.body).to include('Public wish')
      expect(response.body).not_to include('private-trace')
    end

    it 'filters public wishlist by status, priority and brand' do
      create(:wishlist_item, user: user, name: 'Matching wish', brand: 'Mini GT',
                             status: 'reserved', priority: 'dream')
      create(:wishlist_item, user: user, name: 'Other wish', brand: 'Hot Wheels',
                             status: 'wanted', priority: 'low')

      get public_wishlist_path(user.wishlist_share_token),
          params: { status: 'reserved', priority: 'dream', brand: 'Mini GT' }

      expect(response.body).to include('Matching wish')
      expect(response.body).not_to include('Other wish')
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
end

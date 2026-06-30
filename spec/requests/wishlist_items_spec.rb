# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WishlistItems', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /wishlist' do
    it 'renders only the current user wishlist items' do
      own_item = create(:wishlist_item, user: user, name: 'Visible wish')
      create(:wishlist_item, user: other_user, name: 'Private wish')

      get wishlist_items_path

      expect(response).to be_successful
      expect(response.body).to include(own_item.name)
      expect(response.body).not_to include('Private wish')
    end

    it 'filters by status, priority, brand and query' do
      matching = create(
        :wishlist_item,
        user: user,
        name: 'Blue Porsche',
        brand: 'Mini GT',
        status: 'reserved',
        priority: 'high'
      )
      create(:wishlist_item, user: user, name: 'Red Ferrari', brand: 'Hot Wheels',
                             status: 'wanted', priority: 'low')

      get wishlist_items_path,
          params: { q: 'Porsche', brand: 'Mini GT', status: 'reserved', priority: 'high' }

      expect(response.body).to include(matching.name)
      expect(response.body).not_to include('Red Ferrari')
    end
  end

  describe 'POST /wishlist' do
    it 'creates a wishlist item scoped to the current user' do
      expect do
        post wishlist_items_path, params: {
          wishlist_item: {
            name: 'Nissan Skyline',
            brand: 'Tomica',
            scale: '1:64',
            status: 'wanted',
            priority: 'dream',
            target_price_cents: 12_990,
            reference_url: 'https://example.com/skyline'
          }
        }
      end.to change(user.wishlist_items, :count).by(1)

      expect(response).to redirect_to(wishlist_items_path)
      expect(user.wishlist_items.last.name).to eq('Nissan Skyline')
    end

    it 'does not create with unsafe reference URL' do
      expect do
        post wishlist_items_path, params: {
          wishlist_item: {
            name: 'Unsafe URL',
            status: 'wanted',
            priority: 'medium',
            reference_url: 'javascript:alert(1)'
          }
        }
      end.not_to change(user.wishlist_items, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /wishlist/:id' do
    it 'updates a wishlist item owned by the current user' do
      item = create(:wishlist_item, user: user)

      patch wishlist_item_path(item), params: {
        wishlist_item: {
          name: 'Updated wish',
          brand: item.brand,
          scale: item.scale,
          status: 'reserved',
          priority: 'high'
        }
      }

      expect(response).to redirect_to(wishlist_items_path)
      expect(item.reload.status).to eq('reserved')
      expect(item.name).to eq('Updated wish')
    end

    it 'does not update another user wishlist item' do
      item = create(:wishlist_item, user: other_user)

      patch wishlist_item_path(item), params: {
        wishlist_item: {
          name: 'Intrusion',
          status: 'purchased',
          priority: 'high'
        }
      }

      expect(item.reload.name).not_to eq('Intrusion')
      expect(item.status).to eq('wanted')
    end
  end

  describe 'DELETE /wishlist/:id' do
    it 'destroys a wishlist item owned by the current user' do
      item = create(:wishlist_item, user: user)

      expect do
        delete wishlist_item_path(item)
      end.to change(user.wishlist_items, :count).by(-1)

      expect(response).to redirect_to(wishlist_items_path)
    end
  end

  describe 'POST /wishlist/:id/add_to_collection' do
    it 'redirects to a prefilled new car form for the current user item' do
      item = create(:wishlist_item, user: user, name: 'Mazda RX-7', brand: 'Mini GT', scale: '1:64')

      post add_to_collection_wishlist_item_path(item)

      expect(response).to redirect_to(
        new_car_path(
          wishlist_item_id: item.id.to_s,
          car: {
            name: 'Mazda RX-7',
            brand: 'Mini GT',
            size: '1:64',
            observations: item.observations,
            remote_photo_url: item.photo.url
          }.compact_blank
        )
      )
    end

    it 'does not redirect another user wishlist item into the car form' do
      item = create(:wishlist_item, user: other_user)

      post add_to_collection_wishlist_item_path(item)

      expect(response).not_to redirect_to(/wishlist_item_id=#{item.id}/)
    end
  end
end

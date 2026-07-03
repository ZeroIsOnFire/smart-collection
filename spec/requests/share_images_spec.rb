# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ShareImages', type: :request do
  let(:user) { create(:user, wishlist_sharing_enabled: true, wishlist_share_token: 'wishlist-token') }
  let(:other_user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /cars/:car_id/share_image.png' do
    it 'generates a PNG for a current user car' do
      car = create(:car, user: user)

      get car_share_image_path(car, format: :png)

      expect(response).to be_successful
      expect(response.media_type).to eq('image/png')
      expect(response.body).to start_with("\x89PNG".b)
    end

    it 'uses the share image cache for current user cars' do
      car = create(:car, user: user)
      png = "\x89PNG\r\n\x1A\ncached".b

      allow(ShareImageCacheService).to receive(:fetch).with(record: car, kind: :car).and_return(png)

      get car_share_image_path(car, format: :png)

      expect(response).to be_successful
      expect(response.body).to eq(png)
      expect(ShareImageCacheService).to have_received(:fetch).with(record: car, kind: :car)
    end

    it 'renders an in-app preview modal for a current user car' do
      car = create(:car, user: user, name: 'Preview car')

      get car_share_image_path(car), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('turboModal')
      expect(response.body).to include(car_share_image_path(car, format: :png))
      expect(response.body).to include('Preview car')
      expect(response.body).to include('data-controller="share-image-preview"')
      expect(response.body).to include(I18n.t('share_images.preview.loading'))
    end

    it 'does not generate an image for another user car' do
      car = create(:car, user: other_user)

      get car_share_image_path(car, format: :png)

      expect(response).not_to be_successful
    end
  end

  describe 'GET /s/:share_token/car/:id/share_image.png' do
    it 'renders an in-app preview modal for a public car' do
      public_user = create(:user, sharing_enabled: true, share_token: 'public-car-token')
      car = create(:car, user: public_user, name: 'Public preview car')

      get public_car_share_image_path(public_user.share_token, car), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('turboModal')
      expect(response.body).to include(public_car_share_image_path(public_user.share_token, car, format: :png))
      expect(response.body).to include('Public preview car')
      expect(response.body).to include('data-controller="share-image-preview"')
    end

    it 'does not generate an image when public sharing is disabled' do
      private_user = create(:user, sharing_enabled: false, share_token: 'private-car-token')
      car = create(:car, user: private_user)

      get public_car_share_image_path(private_user.share_token, car, format: :png)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /wishlist/:wishlist_item_id/share_image.png' do
    it 'generates a PNG for a current user wishlist item' do
      item = create(:wishlist_item, user: user)

      get wishlist_item_share_image_path(item, format: :png)

      expect(response).to be_successful
      expect(response.media_type).to eq('image/png')
      expect(response.body).to start_with("\x89PNG".b)
    end

    it 'renders an in-app preview modal for a current user wishlist item' do
      item = create(:wishlist_item, user: user, name: 'Preview wish')

      get wishlist_item_share_image_path(item), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('turboModal')
      expect(response.body).to include(wishlist_item_share_image_path(item, format: :png))
      expect(response.body).to include('Preview wish')
      expect(response.body).to include('data-controller="share-image-preview"')
      expect(response.body).to include(I18n.t('share_images.preview.loading'))
    end

    it 'does not generate an image for another user wishlist item' do
      item = create(:wishlist_item, user: other_user)

      get wishlist_item_share_image_path(item, format: :png)

      expect(response).not_to be_successful
    end
  end

  describe 'GET /wishlist/share_image.png' do
    it 'generates a PNG for the current user wishlist list' do
      create(:wishlist_item, user: user)

      get wishlist_share_image_path(format: :png)

      expect(response).to be_successful
      expect(response.media_type).to eq('image/png')
      expect(response.body).to start_with("\x89PNG".b)
    end
  end

  describe 'GET /wishlist/public/:token/image.png' do
    it 'generates a PNG for a publicly shared wishlist without login' do
      sign_out user
      create(:wishlist_item, user: user)

      get public_wishlist_share_image_path(user.wishlist_share_token, format: :png)

      expect(response).to be_successful
      expect(response.media_type).to eq('image/png')
      expect(response.body).to start_with("\x89PNG".b)
    end

    it 'blocks public image generation when wishlist sharing is disabled' do
      user.update!(wishlist_sharing_enabled: false)

      get public_wishlist_share_image_path(user.wishlist_share_token, format: :png)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /wishlist/public/:token/items/:id/share_image.png' do
    it 'generates a PNG for a publicly shared wishlist item without login' do
      sign_out user
      item = create(:wishlist_item, user: user)

      get public_wishlist_item_share_image_path(user.wishlist_share_token, item, format: :png)

      expect(response).to be_successful
      expect(response.media_type).to eq('image/png')
      expect(response.body).to start_with("\x89PNG".b)
    end

    it 'renders an in-app preview modal for a publicly shared wishlist item' do
      sign_out user
      item = create(:wishlist_item, user: user, name: 'Public preview wish')

      get public_wishlist_item_share_image_path(user.wishlist_share_token, item), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('turboModal')
      expect(response.body).to include(public_wishlist_item_share_image_path(user.wishlist_share_token, item, format: :png))
      expect(response.body).to include('Public preview wish')
    end

    it 'blocks public item image generation when wishlist sharing is disabled' do
      item = create(:wishlist_item, user: user)
      user.update!(wishlist_sharing_enabled: false)

      get public_wishlist_item_share_image_path(user.wishlist_share_token, item, format: :png)

      expect(response).to have_http_status(:not_found)
    end
  end
end

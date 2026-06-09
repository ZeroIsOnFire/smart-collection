# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public Collections', type: :request do
  let(:user) { create(:user, sharing_enabled: true, share_token: 'test-token') }
  let!(:car) { create(:car, user: user, name: 'Public Car') }

  describe 'GET /s/:share_token' do
    it 'allows access without login' do
      get public_share_path(user.share_token)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t('public_collections.index.title', name: user.name))
      expect(response.body).to include('Public Car')
    end

    it 'renders public view modes without carousel and opens public cards in a modal' do
      get public_share_path(user.share_token)

      document = Nokogiri::HTML(response.body)
      view_toggle = document.at_css('[data-view-toggle-storage-key-value="public_collection_view_preference"]')
      carousel = document.at_css('#publicCollectionCarousel')
      carousel_button = document.at_css('[data-action="click->view-toggle#setCarousel"]')
      public_card_link = document.at_css("#cars_grid_inner a[href='#{public_share_car_path(user.share_token, car)}']")

      expect(view_toggle['data-view-toggle-storage-key-value']).to eq('public_collection_view_preference')
      expect(carousel).to be_nil
      expect(carousel_button).to be_nil
      expect(public_card_link['data-turbo-frame']).to eq('modal')
      expect(response.body).not_to include('public-carousel-viewport')
      expect(response.body).to include('data-search-form-target="spinner"')
    end

    it 'paginates the public collection' do
      create_list(:car, 20, user: user)

      get public_share_path(user.share_token)

      expect(response).to have_http_status(:success)
      expect(response.body.scan('id="cars_sentinel"').size).to eq(1)

      get public_share_path(user.share_token), params: { page: 2 }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('turbo-stream action="replace" target="cars_sentinel"')
      expect(response.body).to include('turbo-stream action="remove" target="cars_sentinel"')
    end

    it 'redirects to landing page if sharing is disabled' do
      user.update(sharing_enabled: false)
      get public_share_path(user.share_token)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t('errors.messages.page_not_found', default: 'Página ou item não encontrado.'))
    end

    it 'redirects to landing page for invalid token' do
      get public_share_path('invalid-token')
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t('errors.messages.page_not_found', default: 'Página ou item não encontrado.'))
    end
  end

  describe 'GET /s/:share_token/car/:id' do
    it 'allows access to car details without login' do
      get public_share_car_path(user.share_token, car.id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Public Car')
    end

    it 'renders public car details inside the global modal frame' do
      car.update!(
        color: 'Azul',
        size: '1:64',
        observations: 'Versão especial com pintura azul e caixa preservada.'
      )

      get public_share_car_path(user.share_token, car.id), headers: { 'Turbo-Frame' => 'modal' }

      document = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('id="turboModal"')
      expect(response.body).to include('turbo-public-car-modal')
      expect(response.body).to include('Public Car')
      expect(response.body).to include(I18n.t('activerecord.attributes.car.color'))
      expect(response.body).to include('Azul')
      expect(response.body).to include('1:64')
      expect(document.at_css('.public-detail-notes')).to be_present
    end
  end
end

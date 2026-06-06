# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public Collections', type: :request do
  let(:user) { create(:user, sharing_enabled: true, share_token: 'test-token') }
  let!(:car) { create(:car, user: user, name: 'Public Car') }

  describe 'GET /s/:share_token' do
    it 'allows access without login' do
      get public_share_path(user.share_token)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Coleção de')
      expect(response.body).to include('Public Car')
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
  end
end

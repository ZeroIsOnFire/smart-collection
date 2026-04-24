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

    it 'returns 404 if sharing is disabled' do
      user.update(sharing_enabled: false)
      get public_share_path(user.share_token)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for invalid token' do
      get public_share_path('invalid-token')
      expect(response).to have_http_status(:not_found)
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

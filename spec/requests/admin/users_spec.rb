# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Users', type: :request do
  let(:admin) { create(:user, admin: true) }

  before do
    sign_in admin
  end

  describe 'GET /admin/users' do
    it 'paginates the users list' do
      create_list(:user, 21)

      get admin_users_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Página 1 de 2')
      expect(response.body).to include('/admin/users?page=2')

      get admin_users_path, params: { page: 2 }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Página 2 de 2')
      expect(response.body).to include('/admin/users')
      expect(response.body).not_to include('/admin/users?page=3')
    end
  end
end

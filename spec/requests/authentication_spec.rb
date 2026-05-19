# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentications', type: :request do
  let(:user) { User.create(name: 'Usuário Teste', email: 'user@example.com', password: 'password123', admin: false) }
  let(:admin) { User.create(name: 'Admin Teste', email: 'admin@example.com', password: 'password123', admin: true) }

  describe 'GET /users/sign_up' do
    it 'returns http success' do
      get new_user_registration_path
      expect(response).to have_http_status(:success)
    end

    it 'includes the registration form with name field' do
      get new_user_registration_path
      expect(response.body).to include('form')
      expect(response.body).to include('user_name')
      expect(response.body).to include('user_email_signup')
      expect(response.body).to include('user_password_signup')
    end
  end

  describe 'POST /users' do
    context 'with valid params' do
      it 'creates a new user with name and redirects' do
        expect do
          post user_registration_path, params: {
            user: {
              name: 'Novo Usuário',
              email: 'newuser@example.com',
              password: 'password123',
              password_confirmation: 'password123'
            }
          }
        end.to change(User, :count).by(1)
        expect(response).to redirect_to(cars_path)
      end
    end

    context 'with invalid params' do
      it 'does not create a user without name' do
        expect do
          post user_registration_path, params: {
            user: { name: '', email: 'bad@example.com', password: 'password123', password_confirmation: 'password123' }
          }
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create a user with a short password' do
        expect do
          post user_registration_path, params: {
            user: { name: 'Usuário', email: 'bad@example.com', password: '123', password_confirmation: '123' }
          }
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create a user with mismatched passwords' do
        expect do
          post user_registration_path, params: {
            user: { name: 'Usuário', email: 'bad@example.com', password: 'password123', password_confirmation: 'wrong' }
          }
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /users/sign_in' do
    it 'renders dark autofill overrides for the email field' do
      get new_user_session_path

      expect(response.body).to include(':-webkit-autofill')
      expect(response.body).to include('-webkit-text-fill-color: #f1f5f9')
    end

    it 'redirects a normal user to root' do
      post user_session_path, params: { user: { email: user.email, password: 'password123' } }
      expect(response).to redirect_to(cars_path)
    end

    it 'redirects an admin user to admin dashboard' do
      post user_session_path, params: { user: { email: admin.email, password: 'password123' } }
      expect(response).to redirect_to(admin_dashboard_path)
    end
  end

  describe 'Accessing Admin Dashboard' do
    it 'prevents normal user from accessing admin dashboard' do
      sign_in user
      get admin_dashboard_path
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Not authorized')
    end

    it 'allows admin user to access admin dashboard' do
      sign_in admin
      get admin_dashboard_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Dashboard Administrativo')
    end
  end
end

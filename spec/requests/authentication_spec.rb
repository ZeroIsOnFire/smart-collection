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

    it 'renders password visibility controls for password fields' do
      get new_user_registration_path

      document = Nokogiri::HTML(response.body)
      password_field = document.at_css('#user_password_signup')
      confirmation_field = document.at_css('#user_password_confirmation')

      expect(password_field['data-password-visibility-target']).to eq('input')
      expect(confirmation_field['data-password-visibility-target']).to eq('input')
      expect(document.css("[data-controller='password-visibility']").size).to eq(2)
      expect(document.css("[data-action='password-visibility#toggle']").size).to eq(2)
      expect(response.body).to include(I18n.t('devise.ui.password_visibility.show'))
    end
  end

  describe 'POST /users' do
    context 'with valid params' do
      it 'creates a new user with name and redirects to initial setup' do
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
        expect(response).to redirect_to(initial_setup_path)
        expect(User.last.initial_setup_completed).to be false
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
      global_css = Rails.root.join('app/assets/stylesheets/application.css').read

      expect(response.body).to include(':-webkit-autofill')
      expect(response.body).to include(':-webkit-autofill:active')
      expect(response.body).to include('-webkit-text-fill-color: #f1f5f9')
      expect(global_css).to include('[data-theme="dark"] .form-control:-webkit-autofill:active')
      expect(global_css).to include('-webkit-box-shadow: 0 0 0 1000px var(--input-bg) inset !important')
    end

    it 'renders submit loading feedback hooks on the login form' do
      get new_user_session_path

      document = Nokogiri::HTML(response.body)
      form = document.at_css("form[data-controller='auth-submit']")
      submit_button = document.at_css('#sign_in_submit')

      expect(form['data-action']).to include('submit->auth-submit#start')
      expect(submit_button['data-auth-submit-target']).to include('submit')
      expect(submit_button.at_css("[data-auth-submit-target='spinner']")).to be_present
      expect(submit_button.at_css("[data-auth-submit-target='label']").text).to include(I18n.t('devise.ui.sessions.new.submit'))
      expect(response.body).to include(I18n.t('javascript.auth_submit.loading'))
    end

    it 'renders a password visibility control' do
      get new_user_session_path

      document = Nokogiri::HTML(response.body)
      password_field = document.at_css('#user_password_login')
      toggle_button = document.at_css("[data-action='password-visibility#toggle']")

      expect(password_field['data-password-visibility-target']).to eq('input')
      expect(toggle_button['aria-controls']).to eq('user_password_login')
      expect(toggle_button['aria-label']).to eq(I18n.t('devise.ui.password_visibility.show'))
    end

    it 'redirects a normal user to the collection' do
      post user_session_path, params: { user: { email: user.email, password: 'password123' } }
      expect(response).to redirect_to(cars_path)
    end

    it 'redirects a user with pending setup to initial setup' do
      user.update!(initial_setup_completed: false)

      post user_session_path, params: { user: { email: user.email, password: 'password123' } }

      expect(response).to redirect_to(initial_setup_path)
    end

    it 'redirects an admin user to admin dashboard' do
      post user_session_path, params: { user: { email: admin.email, password: 'password123' } }
      expect(response).to redirect_to(admin_dashboard_path)
    end
  end

  describe 'GET /users/edit' do
    before do
      sign_in user
    end

    it 'shows the AI upscaling setting when the service is configured' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      get edit_user_registration_path

      expect(response.body).to include('ai_upscaling_settings_toggle')
      expect(response.body).to include(toggle_ai_upscaling_cars_path)
      expect(response.body).to include(I18n.t('devise.ui.registrations.edit.ai_upscaling_note'))
      expect(response.body).not_to include('user_ai_upscaling_enabled')
    end

    it 'hides the AI upscaling setting when the service is not configured' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(false)

      get edit_user_registration_path

      expect(response.body).not_to include('ai_upscaling_settings_toggle')
      expect(response.body).not_to include('user_ai_upscaling_enabled')
    end
  end

  describe 'PATCH /users' do
    before do
      sign_in user
    end

    it 'does not update the AI upscaling preference through the account form' do
      patch user_registration_path, params: {
        user: {
          name: user.name,
          email: user.email,
          ai_upscaling_enabled: '0',
          current_password: 'password123'
        }
      }

      expect(user.reload.ai_upscaling_enabled).to be true
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

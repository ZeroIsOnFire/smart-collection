# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Initial setup', type: :request do
  let(:user) { create(:user, initial_setup_completed: false) }

  before do
    sign_in user
  end

  describe 'GET /initial-setup' do
    it 'keeps the setup route in English' do
      expect(initial_setup_path).to eq('/initial-setup')
    end

    it 'renders the initial setup form for a user pending setup' do
      get initial_setup_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t('initial_setup.title'))
      expect(response.body).to include('user_sharing_enabled')
      expect(response.body).to include('user_ai_upscaling_enabled')
      expect(response.body).to include('initial-setup-switch')
    end

    it 'redirects users who already completed setup' do
      user.update!(initial_setup_completed: true)

      get initial_setup_path

      expect(response).to redirect_to(cars_path)
    end

    it 'redirects admins away from setup' do
      admin = create(:user, admin: true, initial_setup_completed: false)
      sign_in admin

      get initial_setup_path

      expect(response).to redirect_to(admin_dashboard_path)
    end
  end

  describe 'PATCH /initial-setup' do
    it 'saves public sharing and AI preferences and completes setup' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      patch initial_setup_path, params: {
        user: {
          sharing_enabled: '1',
          ai_upscaling_enabled: '0'
        }
      }

      expect(response).to redirect_to(cars_path)
      expect(user.reload.initial_setup_completed).to be true
      expect(user.sharing_enabled).to be true
      expect(user.share_token).to be_present
      expect(user.ai_upscaling_enabled).to be false
    end

    it 'does not change AI preference when the service is not configured' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(false)

      patch initial_setup_path, params: {
        user: {
          sharing_enabled: '0',
          ai_upscaling_enabled: '0'
        }
      }

      expect(user.reload.initial_setup_completed).to be true
      expect(user.ai_upscaling_enabled).to be true
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Statistics', type: :request do
  let(:admin) { create(:user, admin: true) }
  let(:regular_user) { create(:user) }

  describe 'GET /admin/statistics' do
    context 'quando autenticado como admin' do
      before { sign_in admin }

      it 'retorna status 200 e exibe a pagina de estatisticas' do
        UsageMetric.record!('yolo_detected_items', by: 4)
        UsageMetric.record!('photos_upscaled_ai')

        get admin_statistics_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t('admin.statistics.title'))
        expect(response.body).to include(I18n.t('admin.statistics.counters.yolo_detected_items'))
        expect(response.body).to include('4')
        expect(response.body).to include(I18n.t('admin.statistics.counters.photos_upscaled_ai'))
      end
    end

    context 'quando autenticado como usuario comum' do
      before { sign_in regular_user }

      it 'redireciona para a pagina inicial' do
        get admin_statistics_path

        expect(response).to redirect_to(root_path)
      end
    end

    context 'quando nao autenticado' do
      it 'redireciona para login' do
        get admin_statistics_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end

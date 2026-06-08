# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Dashboard', type: :request do
  let(:admin) { create(:user, admin: true) }
  let(:regular_user) { create(:user) }

  describe 'GET /admin' do
    context 'quando autenticado como admin' do
      before { sign_in admin }

      it 'retorna status 200 e exibe os KPIs' do
        get admin_dashboard_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Dashboard Administrativo')
        expect(response.body).to include('Total de Usuários')
        expect(response.body).to include('Carros no Acervo')
        expect(response.body).to include('Itens via IA')
        expect(response.body).to include('Fila de IA')
      end

      it 'exibe os links de recursos rápidos funcionais' do
        get admin_dashboard_path

        expect(response.body).to include(admin_users_path)
        expect(response.body).to include(admin_statistics_path)
        expect(response.body).to include(admin_maintenance_path)
      end
    end

    context 'quando autenticado como usuário comum' do
      before { sign_in regular_user }

      it 'redireciona para a página inicial com alerta de não autorizado' do
        get admin_dashboard_path

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Not authorized')
      end
    end

    context 'quando não autenticado' do
      it 'redireciona para a página de login' do
        get admin_dashboard_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end

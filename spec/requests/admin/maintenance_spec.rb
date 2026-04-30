# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Maintenance', type: :request do
  let(:admin) { create(:user, admin: true) }
  let(:regular_user) { create(:user) }

  describe 'GET /admin/maintenance' do
    context 'quando autenticado como admin' do
      before { sign_in admin }

      it 'retorna status 200 e exibe o painel de manutenção' do
        get admin_maintenance_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Manutenção do Sistema')
        expect(response.body).to include('Armazenamento')
        expect(response.body).to include('Itens Expirados')
        expect(response.body).to include('Processos de Fundo')
        expect(response.body).to include('Sidekiq')
      end

      it 'exibe a contagem correta de registros expirados' do
        # Registro expirado (mais de 24h com status completed)
        old = create(:autodetection, user: admin, status: 'completed')
        old.set(updated_at: 48.hours.ago)
        # Registro recente (não deve aparecer na contagem)
        create(:autodetection, user: admin, status: 'completed')
        # Registro pendente (não deve aparecer na contagem)
        create(:autodetection, user: admin, status: 'pending')

        get admin_maintenance_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('1')
      end
    end

    context 'quando autenticado como usuário comum' do
      before { sign_in regular_user }

      it 'redireciona para a página inicial com alerta de não autorizado' do
        get admin_maintenance_path

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Not authorized')
      end
    end

    context 'quando não autenticado' do
      it 'redireciona para a página de login' do
        get admin_maintenance_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST /admin/maintenance/cleanup' do
    context 'quando autenticado como admin' do
      before { sign_in admin }

      it 'encaminha o job de limpeza e redireciona com notice' do
        expect(CleanupAutodetectionsJob).to receive(:perform_later)

        post admin_maintenance_cleanup_path

        expect(response).to redirect_to(admin_maintenance_path)
        follow_redirect!
        expect(response.body).to include('Limpeza de arquivos temporários disparada com sucesso.')
      end
    end

    context 'quando autenticado como usuário comum' do
      before { sign_in regular_user }

      it 'redireciona para a página inicial com alerta de não autorizado' do
        post admin_maintenance_cleanup_path

        expect(response).to redirect_to(root_path)
      end
    end
  end
end

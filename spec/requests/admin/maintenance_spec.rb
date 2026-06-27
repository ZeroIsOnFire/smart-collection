# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/api'

RSpec.describe 'Admin::Maintenance', type: :request do
  let(:admin) { create(:user, admin: true) }
  let(:regular_user) { create(:user) }

  before do
    stats = instance_double(Sidekiq::Stats, processed: 10, enqueued: 1, failed: 0)
    workers = instance_double(Sidekiq::Workers, size: 2)

    allow(Sidekiq::Stats).to receive(:new).and_return(stats)
    allow(Sidekiq::Workers).to receive(:new).and_return(workers)
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?).with('public/uploads').and_return(true)
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with(File.join('public/uploads', '**', '*')).and_return([])
  end

  describe 'GET /admin/maintenance' do
    context 'quando autenticado como admin' do
      before { sign_in admin }

      it 'retorna status 200 e exibe o painel de manutencao' do
        get admin_maintenance_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t('admin.maintenance.title'))
        expect(response.body).to include(I18n.t('admin.maintenance.storage.title'))
        expect(response.body).to include(I18n.t('admin.maintenance.cleanup.title'))
        expect(response.body).to include(I18n.t('admin.maintenance.background_jobs.title'))
        expect(response.body).to include('Sidekiq')
      end

      it 'exibe a contagem correta de registros expirados' do
        old = create(:autodetection, user: admin, status: 'completed')
        old.set(updated_at: 48.hours.ago)
        create(:autodetection, user: admin, status: 'completed')
        create(:autodetection, user: admin, status: 'pending')

        get admin_maintenance_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('1')
      end
    end

    context 'quando autenticado como usuario comum' do
      before { sign_in regular_user }

      it 'redireciona para a pagina inicial com alerta de nao autorizado' do
        get admin_maintenance_path

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Not authorized')
      end
    end

    context 'quando nao autenticado' do
      it 'redireciona para a pagina de login' do
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
        expect(response.body).to include(I18n.t('admin.maintenance.cleanup.notice'))
      end
    end

    context 'quando autenticado como usuario comum' do
      before { sign_in regular_user }

      it 'redireciona para a pagina inicial com alerta de nao autorizado' do
        post admin_maintenance_cleanup_path

        expect(response).to redirect_to(root_path)
      end
    end
  end
end

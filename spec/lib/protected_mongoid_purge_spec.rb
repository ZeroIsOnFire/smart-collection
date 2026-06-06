# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProtectedMongoidPurge do
  subject(:purge) { described_class.call(mongoid: mongoid, rails_env: rails_env) }

  let(:mongoid) { class_double(Mongoid, default_client: client) }
  let(:client) { instance_double(Mongo::Client, database: database) }
  let(:database) { instance_double(Mongo::Database, name: database_name) }
  let(:rails_env) { ActiveSupport::StringInquirer.new(environment_name) }

  context 'quando o ambiente e o banco sao de teste' do
    let(:environment_name) { 'test' }
    let(:database_name) { 'smart_collection_catalog_test' }

    it 'permite limpar o banco de teste' do
      expect(mongoid).to receive(:purge!)

      purge
    end
  end

  context 'quando o ambiente e de teste mas o banco nao parece de teste' do
    let(:environment_name) { 'test' }
    let(:database_name) { 'smart_collection_catalog_development' }

    it 'bloqueia a limpeza para proteger dados locais' do
      expect(mongoid).not_to receive(:purge!)

      expect { purge }.to raise_error(described_class::UnsafeDatabaseError, /Refusing to purge/)
    end
  end

  context 'quando o ambiente nao e de teste' do
    let(:environment_name) { 'development' }
    let(:database_name) { 'smart_collection_catalog_test' }

    it 'bloqueia a limpeza mesmo quando o nome do banco contem test' do
      expect(mongoid).not_to receive(:purge!)

      expect { purge }.to raise_error(described_class::UnsafeDatabaseError, /Refusing to purge/)
    end
  end
end

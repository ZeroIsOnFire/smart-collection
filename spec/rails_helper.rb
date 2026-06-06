# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
Rails.root.glob('spec/support/**/*.rb').each { |f| require f }
begin
  Rails.application.middleware.delete(ActionDispatch::HostAuthorization)
rescue StandardError
  nil
end
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'

begin
  # ActiveRecord is commented out in application.rb, so we skip migrations check
  # ActiveRecord::Migration.maintain_test_schema!
rescue NameError
  # ActiveRecord not defined
end

RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include ActiveJob::TestHelper

  config.before do
    ProtectedMongoidPurge.call
    CarService.remove_instance_variable(:@text_search_index_checked) if defined?(CarService) && CarService.instance_variable_defined?(:@text_search_index_checked)
    clear_enqueued_jobs
    clear_performed_jobs
  end
end

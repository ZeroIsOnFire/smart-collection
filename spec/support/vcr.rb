# frozen_string_literal: true

require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false

  # Hide sensitive data from cassettes
  config.filter_sensitive_data('<GOOGLE_CLOUD_PROJECT_ID>') { ENV.fetch('GOOGLE_CLOUD_PROJECT_ID', nil) }
  config.filter_sensitive_data('<GOOGLE_CLOUD_CREDENTIALS_PATH>') { ENV.fetch('GOOGLE_CLOUD_CREDENTIALS_PATH', nil) }
end

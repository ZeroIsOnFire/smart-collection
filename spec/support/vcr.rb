require 'vcr'
require 'webmock/rspec'

puts "VCR config loaded"

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false

  # Hide sensitive data from cassettes
  config.filter_sensitive_data('<GOOGLE_CLOUD_PROJECT_ID>') { ENV['GOOGLE_CLOUD_PROJECT_ID'] }
  config.filter_sensitive_data('<GOOGLE_CLOUD_CREDENTIALS_PATH>') { ENV['GOOGLE_CLOUD_CREDENTIALS_PATH'] }
end

# frozen_string_literal: true

return unless ENV.fetch('OBSERVABILITY_ENABLED', 'false') == 'true'

require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'prometheus/client/formats/text'

OpenTelemetry::SDK.configure do |config|
  config.service_name = ENV.fetch('OTEL_SERVICE_NAME', 'smart-collection-web')
end

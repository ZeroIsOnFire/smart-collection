# frozen_string_literal: true

require 'prometheus/client/formats/text'

class MetricsController < ApplicationController
  def show
    return head :not_found unless Observability.enabled?

    ObservabilityMetrics.refresh_sidekiq!
    self.content_type = 'text/plain; version=0.0.4'
    self.response_body = Prometheus::Client::Formats::Text.marshal(ObservabilityMetrics::REGISTRY)
  end
end

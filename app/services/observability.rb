# frozen_string_literal: true

module Observability
  module_function

  def enabled?
    ENV.fetch('OBSERVABILITY_ENABLED', 'false') == 'true'
  end

  def tracer
    OpenTelemetry.tracer_provider.tracer('smart_collection.observability', '1.0')
  end

  def in_span(name, attributes = {}, &block)
    return block.call unless enabled?

    tracer.in_span(name, attributes: attributes, &block)
  end

  def inject_trace_context!(carrier)
    OpenTelemetry.propagation.inject(carrier) if enabled?
  end
end

# frozen_string_literal: true

class SidekiqTraceContextMiddleware
  def call(_worker_class, job, _queue, _redis_pool)
    Observability.inject_trace_context!(job)
    yield
  end
end

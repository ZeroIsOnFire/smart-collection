# frozen_string_literal: true

Rails.application.config.action_dispatch.default_headers.merge!(
  'X-Content-Type-Options' => 'nosniff',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Cross-Origin-Opener-Policy' => 'same-origin',
  'Cross-Origin-Resource-Policy' => 'same-origin',
  'Permissions-Policy' => 'accelerometer=(), autoplay=(), camera=(), display-capture=(), ' \
                          'encrypted-media=(), fullscreen=(self), geolocation=(), gyroscope=(), ' \
                          'magnetometer=(), microphone=(), payment=(), usb=()'
)

STATIC_SECURITY_HEADERS = {
  'X-Content-Type-Options' => 'nosniff',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Cross-Origin-Opener-Policy' => 'same-origin',
  'Cross-Origin-Resource-Policy' => 'same-origin',
  'Permissions-Policy' => Rails.application.config.action_dispatch.default_headers['Permissions-Policy']
}.freeze

class StaticSecurityHeaders
  STATIC_PATHS = %w[/assets/ /logo/].freeze
  STATIC_FILES = %w[/robots.txt /sitemap.xml].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    add_headers(headers) if static_path?(env['PATH_INFO'])
    [status, headers, response]
  end

  private

  def static_path?(path)
    STATIC_FILES.include?(path) || STATIC_PATHS.any? { |prefix| path.start_with?(prefix) }
  end

  def add_headers(headers)
    STATIC_SECURITY_HEADERS.each do |header, value|
      headers[header] ||= value
    end
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::Static, StaticSecurityHeaders

Rails.application.config.content_security_policy do |policy|
  websocket_sources = %w[
    ws://localhost:3000
    ws://127.0.0.1:3000
    ws://host.docker.internal:3000
    wss://localhost:3000
    wss://127.0.0.1:3000
    wss://host.docker.internal:3000
  ]

  policy.default_src :self
  policy.base_uri :self
  policy.child_src :self
  policy.connect_src :self, *websocket_sources
  policy.font_src :self, :data, 'https://fonts.gstatic.com', 'https://cdn.jsdelivr.net', 'https://cdnjs.cloudflare.com'
  policy.form_action :self
  policy.frame_ancestors :self
  policy.img_src :self, :data, :blob
  policy.object_src :none
  policy.script_src :self, 'https://cdnjs.cloudflare.com'
  policy.style_src :self, :unsafe_inline, 'https://fonts.googleapis.com', 'https://cdn.jsdelivr.net',
                   'https://cdnjs.cloudflare.com'
end

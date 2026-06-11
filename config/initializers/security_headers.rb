# frozen_string_literal: true

Rails.application.config.action_dispatch.default_headers.merge!(
  'X-Content-Type-Options' => 'nosniff',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Permissions-Policy' => 'accelerometer=(), autoplay=(), camera=(), display-capture=(), ' \
                          'encrypted-media=(), fullscreen=(self), geolocation=(), gyroscope=(), ' \
                          'magnetometer=(), microphone=(), payment=(), usb=()'
)

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.base_uri :self
  policy.child_src :self
  policy.connect_src :self, 'ws:', 'wss:'
  policy.font_src :self, :data, 'https://fonts.gstatic.com', 'https://cdn.jsdelivr.net', 'https://cdnjs.cloudflare.com'
  policy.form_action :self
  policy.frame_ancestors :self
  policy.img_src :self, :data, :blob
  policy.object_src :none
  policy.script_src :self, :unsafe_inline, 'https://cdnjs.cloudflare.com'
  policy.style_src :self, :unsafe_inline, 'https://fonts.googleapis.com', 'https://cdn.jsdelivr.net',
                   'https://cdnjs.cloudflare.com'
end

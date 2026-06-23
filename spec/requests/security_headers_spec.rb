# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security headers', type: :request do
  it 'adds browser hardening headers to HTML responses' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Security-Policy']).to include("default-src 'self'")
    expect(response.headers['Content-Security-Policy']).not_to include('connect-src *')
    expect(response.headers['Permissions-Policy']).to include('camera=()')
    expect(response.headers['Cross-Origin-Opener-Policy']).to eq('same-origin')
    expect(response.headers['Cross-Origin-Resource-Policy']).to eq('same-origin')
    expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    expect(response.body).to include('href="/assets/application-')
    expect(response.body).to include('src="/assets/application-')
    expect(response.body).not_to include('href="https://')
    expect(response.body).not_to include('src="https://')
  end

  it 'adds hardening headers to public static files served by Rails' do
    get '/robots.txt'

    expect(response).to have_http_status(:ok)
    expect(response.headers['Permissions-Policy']).to include('camera=()')
    expect(response.headers['Cross-Origin-Opener-Policy']).to eq('same-origin')
    expect(response.headers['Cross-Origin-Resource-Policy']).to eq('same-origin')
    expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
  end
end

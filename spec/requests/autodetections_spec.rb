# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Autodetections', type: :request do
  let(:user) { create(:user) }
  let(:valid_params) do
    { autodetection: { photo: Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') } }
  end

  before do
    sign_in user
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'POST /create' do
    it 'creates an autodetection and redirects or responds with turbo stream' do
      expect do
        post autodetections_path, params: valid_params, as: :turbo_stream
      end.to change(Autodetection, :count).by(1)
                                          .and enqueue_job(AutodetectJob)
      expect(response).to be_successful
      expect(response.body).to include('turbo-stream action="replace" target="autodetections_panel"')
      expect(response.body).not_to include('turbo-stream action="prepend" target="autodetections_list"')
    end

    it 'ignores the legacy upscaler preference for the autodetection' do
      post autodetections_path,
           params: valid_params.deep_merge(autodetection: { skip_upscaler: '1' }),
           as: :turbo_stream

      expect(response).to be_successful
      expect(Autodetection.last.skip_upscaler).to be false
    end

    it 'shows validation errors below the photo field' do
      expect do
        post autodetections_path, params: { autodetection: {} }, as: :turbo_stream
      end.not_to change(Autodetection, :count)

      expect(response).to be_successful
      expect(response.body).to include('target="autodetection_form_errors"')
      expect(response.body).to include('target="autodetection_photo_errors"')
      expect(response.body).to include(I18n.t('autodetections.form.validation_error_title'))
      expect(response.body).to include(Autodetection.human_attribute_name(:photo))
    end
  end

  describe 'GET /show' do
    let(:autodetection) { create(:autodetection, :completed, user: user) }

    it 'renders the show template' do
      get autodetection_path(autodetection)
      expect(response).to be_successful
    end

    it 'does not show an AI upscaling notice when the autodetection photo used AI' do
      autodetection.update!(photo_upscale_strategy: 'ai')

      get autodetection_path(autodetection)

      document = Nokogiri::HTML(response.body)

      expect(response).to be_successful
      expect(document.at_css('[data-ai-upscaling-notice]')).to be_nil
    end

    it 'does not show the AI upscaling notice for regular autodetections' do
      get autodetection_path(autodetection)

      document = Nokogiri::HTML(response.body)

      expect(response).to be_successful
      expect(document.at_css('[data-ai-upscaling-notice]')).to be_nil
    end
  end

  describe 'GET /cars' do
    it 'does not render the upscaler preference in the autodetection modal' do
      get cars_path

      document = Nokogiri::HTML(response.body)
      preview_toggle = document.at_css(
        '[data-autodetection-upload-target="previewContainer"] #autodetection_skip_upscaler'
      )
      preview_controls = document.at_css(
        '[data-autodetection-upload-target="previewContainer"] [data-autodetection-upload-target="upscalerControls"]'
      )
      upload_toggle = document.at_css(
        '[data-autodetection-upload-target="uploadInterface"] #autodetection_skip_upscaler'
      )
      upload_controller = document.at_css('[data-controller="autodetection-upload"]')

      expect(response).to be_successful
      expect(preview_toggle).to be_nil
      expect(preview_controls).to be_nil
      expect(upload_controller['data-autodetection-upload-minimum-side-value']).to be_nil
      expect(upload_toggle).to be_nil
    end

    it 'renders active autodetection counts by status' do
      create(:autodetection, user: user, status: 'pending')
      create(:autodetection, user: user, status: 'processing')
      create(:autodetection, user: user, status: 'to_verify')
      create(:autodetection, user: user, status: 'error', error_message: 'Falha')
      create(:autodetection, user: user, status: 'completed')
      create(:autodetection, user: create(:user), status: 'to_verify')

      get cars_path

      document = Nokogiri::HTML(response.body)
      panel = document.at_css('#autodetections_panel')
      panel_text = panel.text.squish

      expect(response).to be_successful
      expect(panel).to be_present
      expect(panel_text).to include(I18n.t('autodetections.panel.title', count: 4))
      expect(panel_text).to include("1 #{I18n.t('autodetections.status.pending')}")
      expect(panel_text).to include("1 #{I18n.t('autodetections.status.processing')}")
      expect(panel_text).to include("1 #{I18n.t('autodetections.status.to_verify')}")
      expect(panel_text).to include("1 #{I18n.t('autodetections.status.error')}")
      expect(panel_text).not_to include(I18n.t('autodetections.status.completed'))
    end
  end

  describe 'PATCH /retry' do
    let(:autodetection) { create(:autodetection, :error, user: user) }

    it 'retries the job and redirects' do
      expect do
        patch retry_autodetection_path(autodetection)
      end.to enqueue_job(AutodetectJob)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq('Processo reiniciado.')
    end
  end

  describe 'DELETE /destroy' do
    let!(:autodetection) { create(:autodetection, user: user) }

    it 'removes the autodetection and responds with turbo stream' do
      expect do
        delete autodetection_path(autodetection), as: :turbo_stream
      end.to change(Autodetection, :count).by(-1)

      expect(response).to be_successful
      expect(response.body).to include('turbo-stream action="replace" target="autodetections_panel"')
      expect(response.body).not_to include("turbo-stream action=\"remove\" target=\"autodetection_#{autodetection.id}\"")
    end

    it 'redirects if format is html' do
      expect do
        delete autodetection_path(autodetection)
      end.to change(Autodetection, :count).by(-1)

      expect(response).to redirect_to(cars_path)
    end
  end
end

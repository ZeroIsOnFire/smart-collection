# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DetectedItems', type: :request do
  before do
    @user = create(:user)
    @autodetection = create(:autodetection, user: @user)
    @detected_item = create(:detected_item, autodetection: @autodetection)
    sign_in @user
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'GET /autodetections/:id' do
    it 'renders consistent loading hooks for detected item submissions' do
      @autodetection.update!(status: 'to_verify')

      get autodetection_path(@autodetection)

      document = Nokogiri::HTML(response.body)
      frame = document.at_css("#detected_item_#{@detected_item.id}")
      submit_button = document.at_css("button[data-detected-item-target='submit']")

      expect(response).to have_http_status(:ok)
      expect(frame['data-detected-item-loading-label-value']).to eq(I18n.t('autodetections.messages.saving'))
      expect(response.body).to include('detected-item-loader-content')
      expect(submit_button['data-loading-html']).to include(I18n.t('autodetections.messages.saving'))

      year_input = document.at_css("#year_#{@detected_item.id}")
      name_input = document.at_css("#name_#{@detected_item.id}")

      expect(year_input['data-controller']).to eq('numeric-mask')
      expect(year_input['data-action']).to include('input->numeric-mask#sanitize')
      expect(name_input['data-controller']).not_to eq('numeric-mask')
    end
  end

  describe 'PATCH /update_selection' do
    let(:crop_params) do
      {
        x: 0.2,
        y: 0.2,
        width: 0.5,
        height: 0.5
      }
    end

    it 'updates the detected item position data and enqueues image processing' do
      expect(ImageCropperService).not_to receive(:crop)

      expect do
        patch update_selection_detected_item_path(@detected_item),
              params: crop_params,
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end.to enqueue_job(DetectedItemImageProcessingJob)

      expect(response).to have_http_status(:ok)
      @detected_item.reload

      vertices = @detected_item.position_data['vertices']
      expect(vertices.first['x']).to eq(0.2)
      expect(vertices.last['y']).to eq(0.7) # y + height
      expect(@detected_item.image_processing_status).to eq('pending')
    end

    it 'returns turbo stream response' do
      patch update_selection_detected_item_path(@detected_item),
            params: crop_params,
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response.content_type).to include('text/vnd.turbo-stream.html')
      expect(response.body).to include('turbo-stream')
      expect(response.body).to include('replace')
      expect(response.body).to include("detected_item_#{@detected_item.id}")
    end

    it 'shows validation errors and preserves invalid fields when adjustment submits form values' do
      patch update_selection_detected_item_path(@detected_item),
            params: crop_params.merge(name: '', year: 'abcd'),
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(@detected_item.reload.label).to be_present

      document = Nokogiri::HTML.fragment(response.body)
      name_input = document.at_css("#name_#{@detected_item.id}")
      year_input = document.at_css("#year_#{@detected_item.id}")

      expect(name_input['value']).to be_blank
      expect(year_input['value']).to eq('abcd')
      expect(document.css('.invalid-feedback').map { |node| node.text.squish }).to include(
        I18n.t('errors.messages.blank'),
        I18n.t('errors.messages.not_a_number')
      )
    end
  end

  describe 'POST /create' do
    let(:create_params) do
      {
        x: 0.1,
        y: 0.1,
        width: 0.3,
        height: 0.3
      }
    end

    it 'creates a new detected item manually' do
      expect(ImageCropperService).not_to receive(:crop)

      expect do
        post autodetection_detected_items_path(@autodetection),
             params: create_params,
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end.to change(DetectedItem, :count).by(1)
      expect(DetectedItemImageProcessingJob).to have_been_enqueued

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream')
      expect(response.body).to include('append')
      expect(response.body).to include("detected_items_list_#{@autodetection.id}")

      new_item = DetectedItem.order_by(created_at: :desc).first
      expect(new_item.status).to eq('pending')
      expect(new_item.position_data['score']).to eq(1.0)
      expect(new_item.image_processing_status).to eq('pending')
    end

    it 'appends a local toast on turbo stream success' do
      post autodetection_detected_items_path(@autodetection),
           params: create_params,
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("detected_items_list_#{@autodetection.id}")
      expect(response.body).to include('local_toast_container')
      expect(response.body).to include(I18n.t('autodetections.messages.item_added'))
    end
  end

  describe 'POST /cars from detected item' do
    it 'shows validation errors and preserves blank name in the detected item form' do
      post cars_path,
           params: { detected_item_id: @detected_item.id, car: { name: '', year: 'abcd' } },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(@detected_item.reload.status).to eq('pending')

      document = Nokogiri::HTML.fragment(response.body)
      name_input = document.at_css("#name_#{@detected_item.id}")
      year_input = document.at_css("#year_#{@detected_item.id}")

      expect(name_input['value']).to be_blank
      expect(year_input['value']).to eq('abcd')
      expect(document.css('.invalid-feedback').map { |node| node.text.squish }).to include(
        I18n.t('errors.messages.blank'),
        I18n.t('errors.messages.not_a_number')
      )
    end
  end

  describe 'DELETE /destroy' do
    it 'removes the detected item' do
      expect do
        delete detected_item_path(@detected_item),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end.to change(DetectedItem, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream')
      expect(response.body).to include('remove')
      expect(response.body).to include("detected_item_#{@detected_item.id}")
      expect(response.body).to include('local_toast_container')
      expect(response.body).to include(I18n.t('autodetections.messages.item_removed'))
    end
  end
end

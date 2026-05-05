# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DetectedItems', type: :request do
  before do
    @user = create(:user)
    @autodetection = create(:autodetection, user: @user)
    @detected_item = create(:detected_item, autodetection: @autodetection)
    sign_in @user
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

    it 'updates the detected item position data and photo' do
      # Mock do ImageCropperService para evitar processamento real de imagem nos testes
      allow(ImageCropperService).to receive(:crop).and_return(
        File.open('/rails/spec/fixtures/files/car_sample.jpg')
      )

      patch update_selection_detected_item_path(@detected_item),
            params: crop_params,
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      @detected_item.reload

      vertices = @detected_item.position_data['vertices']
      expect(vertices.first['x']).to eq(0.2)
      expect(vertices.last['y']).to eq(0.7) # y + height
    end

    it 'returns turbo stream response' do
      allow(ImageCropperService).to receive(:crop).and_return(
        File.open('/rails/spec/fixtures/files/car_sample.jpg')
      )

      patch update_selection_detected_item_path(@detected_item),
            params: crop_params,
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response.content_type).to include('text/vnd.turbo-stream.html')
      expect(response.body).to include('turbo-stream')
      expect(response.body).to include('replace')
      expect(response.body).to include("detected_item_#{@detected_item.id}")
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
      allow(ImageCropperService).to receive(:crop).and_return(
        File.open('/rails/spec/fixtures/files/car_sample.jpg')
      )

      expect do
        post autodetection_detected_items_path(@autodetection),
             params: create_params,
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end.to change(DetectedItem, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream')
      expect(response.body).to include('append')
      expect(response.body).to include("detected_items_list_#{@autodetection.id}")

      new_item = DetectedItem.order_by(created_at: :desc).first
      expect(new_item.status).to eq('pending')
      expect(new_item.position_data['score']).to eq(1.0)
    end

    it 'does not append a local toast on turbo stream success' do
      allow(ImageCropperService).to receive(:crop).and_return(
        File.open('/rails/spec/fixtures/files/car_sample.jpg')
      )

      post autodetection_detected_items_path(@autodetection),
           params: create_params,
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("detected_items_list_#{@autodetection.id}")
      expect(response.body).not_to include('local_toast_container')
      expect(response.body).not_to include('Item adicionado com sucesso!')
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
    end
  end
end

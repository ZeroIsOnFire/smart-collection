# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cars', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:car) { create(:car, user: user) }

  let(:valid_attributes) do
    {
      name: 'Civic',
      brand: 'Hot Wheels',
      manufacturer: 'Honda',
      year: 2020
    }
  end

  before do
    sign_in user
  end

  describe 'GET /index' do
    it "renders a successful response and shows only user's cars" do
      car # create
      create(:car, user: other_user)
      get cars_path
      expect(response).to be_successful
    end

    it 'shows the autodetection AI upscaling notice when enabled and configured' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      get cars_path

      expect(response.body).to include(
        I18n.t('autodetections.form.ai_upscaling_notice', minimum_side: AutodetectionService.autodetection_minimum_side)
      )
    end

    it 'paginates the cars collection' do
      create_list(:car, 21, user: user)

      get cars_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('/cars.turbo_stream?page=2')

      get cars_path, params: { page: 2 }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('turbo-stream action="replace" target="cars_sentinel"')
      expect(response.body).to include('turbo-stream action="remove" target="cars_sentinel"')
    end

    context 'with search parameter' do
      before do
        Car.create_indexes
      end

      let!(:car_matching) { create(:car, user: user, name: 'Searchable Car') }
      let!(:car_not_matching) { create(:car, user: user, name: 'Other Car') }

      it 'filters cars by name' do
        get cars_path, params: { q: 'Searchable' }
        expect(response.body).to include('Searchable Car')
        expect(response.body).not_to include('Other Car')
      end

      it 'filters cars by brand' do
        car_matching.update!(brand: 'Toyota')
        get cars_path, params: { q: 'Toyota' }
        expect(response.body).to include('Searchable Car')
      end

      it 'filters cars by manufacturer' do
        car_matching.update!(manufacturer: 'Burago')
        get cars_path, params: { q: 'Burago' }
        expect(response.body).to include('Searchable Car')
      end

      it 'filters cars by tags' do
        car_matching.update!(tags: ['match'])
        get cars_path, params: { q: 'match' }
        expect(response.body).to include('Searchable Car')
      end
    end
  end

  describe 'GET /new' do
    it 'renders a successful response' do
      get new_car_path
      expect(response).to be_successful
    end

    it 'shows the AI upscaling notice when enabled and configured' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      get new_car_path

      expect(response.body).to include(
        I18n.t('cars.form.ai_upscaling_notice', minimum_side: ImageUpscalerService.default_minimum_side)
      )
    end

    it 'hides the AI upscaling notice when the user disables it' do
      user.update!(ai_upscaling_enabled: false)
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      get new_car_path

      expect(response.body).not_to include(
        I18n.t('cars.form.ai_upscaling_notice', minimum_side: ImageUpscalerService.default_minimum_side)
      )
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      it 'creates a new Car' do
        expect do
          post cars_path, params: { car: valid_attributes }
        end.to change(Car, :count).by(1)
      end

      it 'redirects to the created car' do
        post cars_path, params: { car: valid_attributes }
        expect(response).to redirect_to(car_url(Car.last))
      end

      it 'creates a car with a photo' do
        attributes_with_photo = valid_attributes.merge(
          photo: fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
        )
        expect do
          post cars_path, params: { car: attributes_with_photo }
        end.to change(Car, :count).by(1)

        expect(Car.last.photo).to be_present
      end
    end
  end

  describe 'GET /edit' do
    it 'renders a successful response' do
      get edit_car_path(car)
      expect(response).to be_successful
    end

    it "redirects if trying to edit another user's car" do
      other_car = create(:car, user: other_user)
      get edit_car_path(other_car)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /update' do
    context 'with valid parameters' do
      let(:new_attributes) { { name: 'New Name' } }

      it 'updates the requested car' do
        patch car_path(car), params: { car: new_attributes }
        car.reload
        expect(car.name).to eq('New Name')
      end

      it 'redirects to the car list' do
        patch car_path(car), params: { car: new_attributes }
        car.reload
        expect(response).to redirect_to(car_url(car))
      end

      it "removes the photo when remove_photo is '1'" do
        car_with_photo = create(:car, user: user)
        # Give it a photo first
        car_with_photo.photo = fixture_file_upload(
          Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png'
        )
        car_with_photo.save!
        expect(car_with_photo.reload.photo).to be_present

        patch car_path(car_with_photo), params: { car: { remove_photo: '1' } }
        expect(response).to redirect_to(car_url(car_with_photo))
        expect(Car.find(car_with_photo.id).photo).not_to be_present
      end
    end
  end

  describe 'PATCH /toggle_ai_upscaling' do
    it 'toggles the AI upscaling preference with turbo stream' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      patch toggle_ai_upscaling_cars_path, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream action="update" target="ai_upscaling_settings_toggle"')
      expect(user.reload.ai_upscaling_enabled).to be false
    end

    it 'does not toggle the preference when the service is not configured' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(false)

      patch toggle_ai_upscaling_cars_path

      expect(response).to redirect_to(edit_user_registration_path)
      expect(user.reload.ai_upscaling_enabled).to be true
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the requested car' do
      car_to_destroy = create(:car, user: user)
      expect do
        delete car_path(car_to_destroy)
      end.to change(Car, :count).by(-1)
    end

    it 'redirects to the cars list' do
      delete car_path(car)
      expect(response).to redirect_to(cars_path)
    end

    it 'removes the car card when requested as turbo stream' do
      car_to_destroy = create(:car, user: user)

      expect do
        delete car_path(car_to_destroy), as: :turbo_stream
      end.to change(Car, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-stream action=\"remove\" target=\"car_#{car_to_destroy.id}\"")
      expect(response.body).to include('flash_toasts')
      expect(response.body).to include(I18n.t('flash.deleted', resource: I18n.t('activerecord.models.car.one')))
    end

    it 'does not fail when the car is already gone and the remove is retried' do
      car_to_destroy = create(:car, user: user)
      car_id = car_to_destroy.id.to_s

      delete "/cars/#{car_id}", as: :turbo_stream

      expect do
        delete "/cars/#{car_id}", as: :turbo_stream
      end.not_to raise_error
    end

    it 'shows a flash message when destroy raises an error' do
      car_to_destroy = create(:car, user: user)
      service = instance_double(CarService)

      allow(CarService).to receive(:new).and_call_original
      allow(CarService).to receive(:new).with(instance_of(User)).and_return(service)
      allow(service).to receive(:destroy).and_raise(StandardError, 'boom')

      delete car_path(car_to_destroy), as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('flash_toasts')
      expect(response.body).to include(I18n.t('flash.error'))
    end
  end
end

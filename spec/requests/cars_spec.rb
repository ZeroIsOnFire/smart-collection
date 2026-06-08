# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cars', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:car) { create(:car, user: user) }

  let(:valid_attributes) do
    {
      name: 'Honda Civic',
      brand: 'Hot Wheels',
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

    it 'uses immediate local feedback for deletion actions' do
      car

      get cars_path

      document = Nokogiri::HTML(response.body)
      delete_form = document.at_css("form[data-car-removal-car-id='#{car.id}']")
      delete_button = document.at_css("[data-car-removal-trigger][data-car-removal-car-id='#{car.id}']")

      expect(response.body).to include('data-controller="theme car-removal"')
      expect(delete_form['data-turbo-confirm']).to be_nil
      expect(delete_button['data-car-removal-confirm-message']).to eq(I18n.t('items.delete_confirm'))
      expect(delete_button).to be_present
    end

    it 'subscribes to car card updates for background photo processing' do
      get cars_path

      signed_stream = Turbo::StreamsChannel.signed_stream_name("cars_#{user.id}")
      expect(response.body).to include(signed_stream)
    end

    it 'marks the processing text so list view can show only the loading icon' do
      processing_car = create(:car, user: user, photo_processing_status: 'pending')
      processing_car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      processing_car.save!

      get cars_path

      expect(response.body).to include('car-photo-processing-label')
      expect(response.body).to include(I18n.t('cars.card.photo_processing'))
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

      it 'filters cars by vehicle manufacturer included in the name' do
        car_matching.update!(name: 'Burago Ferrari F40')
        get cars_path, params: { q: 'Burago' }
        expect(response.body).to include('Burago Ferrari F40')
        expect(response.body).not_to include('Other Car')
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

    it 'renders the form inside the global modal frame' do
      get new_car_path, headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('id="turboModal"')
      expect(response.body).to include('id="new_car"')
    end

    it 'reuses the latest brand and scale as suggestions for a new item' do
      create(:car, user: user, brand: 'Hot Wheels', size: '1:64')

      get new_car_path

      document = Nokogiri::HTML(response.body)
      brand_field = document.at_css('#car_brand')
      selected_scale = document.at_css('#car_size option[selected]')

      expect(brand_field['value']).to eq('Hot Wheels')
      expect(selected_scale['value']).to eq('1:64')
    end

    it 'renders a quick action to keep adding items' do
      get new_car_path

      document = Nokogiri::HTML(response.body)
      create_another_button = document.at_css("input[name='commit_action'][value='create_another']")

      expect(create_another_button).to be_present
      expect(create_another_button['value']).to eq('create_another')
      expect(create_another_button['data-disable-with']).to include(I18n.t('cars.form.create_another'))
    end

    it 'lets explicit new item params override suggestions' do
      create(:car, user: user, brand: 'Hot Wheels', size: '1:64')

      get new_car_path, params: { car: { brand: 'Matchbox', size: '1:43' } }

      document = Nokogiri::HTML(response.body)
      brand_field = document.at_css('#car_brand')
      selected_scale = document.at_css('#car_size option[selected]')

      expect(brand_field['value']).to eq('Matchbox')
      expect(selected_scale['value']).to eq('1:43')
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

      it 'prepends the created car and closes the modal with turbo stream' do
        expect do
          post cars_path, params: { car: valid_attributes }, as: :turbo_stream
        end.to change(Car, :count).by(1)

        created_car = Car.last
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-stream action="prepend" target="cars_grid_inner"')
        expect(response.body).to include("car_#{created_car.id}")
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include('flash_toasts')
      end

      it 'prepends the created car and keeps the modal ready for another item' do
        expect do
          post cars_path,
               params: { car: valid_attributes, commit_action: 'create_another' },
               as: :turbo_stream
        end.to change(Car, :count).by(1)

        created_car = Car.last
        document = Nokogiri::HTML.fragment(response.body)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-stream action="prepend" target="cars_grid_inner"')
        expect(response.body).to include("car_#{created_car.id}")
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include('id="new_car"')
        expect(response.body).to include('flash_toasts')
        expect(document.at_css('#car_brand')['value']).to eq(valid_attributes[:brand])
      end

      it 'rerenders the modal form when turbo stream validation fails' do
        expect do
          post cars_path, params: { car: valid_attributes.merge(name: '') }, as: :turbo_stream
        end.not_to change(Car, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include('id="turboModal"')
        expect(response.body).to include('new_car')
      end
    end
  end

  describe 'GET /edit' do
    it 'renders a successful response' do
      get edit_car_path(car)
      expect(response).to be_successful
    end

    it 'renders the edit form inside the global modal frame' do
      get edit_car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('id="turboModal"')
      expect(response.body).to include("edit_car_#{car.id}")
      expect(response.body).to include(I18n.t('cars.modal.edit_title'))
    end

    it "redirects if trying to edit another user's car" do
      other_car = create(:car, user: other_user)
      get edit_car_path(other_car)
      expect(response).to redirect_to(cars_path)
      expect(flash[:alert]).to eq(I18n.t('errors.messages.page_not_found', default: 'Página ou item não encontrado.'))
    end
  end

  describe 'GET /show' do
    it 'renders the detail view inside the global modal frame' do
      get car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('id="turboModal"')
      expect(response.body).to include(car.name)
      document = Nokogiri::HTML(response.body)
      delete_form = document.at_css("form[data-car-removal-car-id='#{car.id}']")
      delete_button = document.at_css("[data-car-removal-trigger][data-car-removal-car-id='#{car.id}']")

      expect(delete_form['data-turbo-frame']).to be_nil
      expect(delete_form['data-turbo-confirm']).to be_nil
      expect(delete_button['data-car-removal-confirm-message']).to eq(I18n.t('items.delete_confirm'))
      expect(delete_button).to be_present
    end

    it "does not show another user's car" do
      other_car = create(:car, user: other_user)

      get car_path(other_car)

      expect(response).to redirect_to(cars_path)
      expect(flash[:alert]).to eq(I18n.t('errors.messages.page_not_found', default: 'Página ou item não encontrado.'))
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

      it 'replaces the updated car and closes the modal with turbo stream' do
        patch car_path(car), params: { car: new_attributes }, as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("turbo-stream action=\"replace\" target=\"car_#{car.id}\"")
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include('flash_toasts')
      end

      it 'rerenders the modal form when turbo stream validation fails' do
        patch car_path(car), params: { car: { name: '' } }, as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include('id="turboModal"')
        expect(response.body).to include("edit_car_#{car.id}")
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

      document = Nokogiri::HTML.fragment(response.body)
      remove_stream = document.at_css('turbo-stream[action="remove"]')

      expect(response).to have_http_status(:ok)
      expect(remove_stream['targets']).to eq(%([data-car-card-id="#{car_to_destroy.id}"]))
      expect(response.body).to include('turbo-stream action="update" target="modal"')
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
      expect(response.body).to include('turbo-stream action="update" target="modal"')
      expect(response.body).to include('flash_toasts')
      expect(response.body).to include(I18n.t('flash.error'))
    end
  end
end

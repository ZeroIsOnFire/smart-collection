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
      year: 2020,
      photo: fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
    }
  end

  before do
    sign_in user
  end

  def uploaded_resized_fixture(width:, height:, filename: 'resized.jpg')
    tempfile = Tempfile.new(['request_photo', '.jpg'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(Rails.root.join('spec/fixtures/files/test_image.png'))
    image.resize "#{width}x#{height}!"
    image.write(tempfile.path)
    Rack::Test::UploadedFile.new(tempfile.path, 'image/jpeg', original_filename: filename)
  ensure
    tempfile&.close
  end

  def processed_temp_image(width:, height:, filename: 'processed.jpg', upscale_strategy: nil)
    tempfile = Tempfile.new(['request_processed_photo', '.jpg'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(Rails.root.join('spec/fixtures/files/test_image.png'))
    image.resize "#{width}x#{height}!"
    image.write(tempfile.path)
    tempfile.define_singleton_method(:original_filename) { filename }
    tempfile.define_singleton_method(:content_type) { 'image/jpeg' }
    tempfile.define_singleton_method(:upscale_strategy) { upscale_strategy } if upscale_strategy
    tempfile
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

    it 'copies the public sharing link with the current locale' do
      user.update!(sharing_enabled: true, locale: 'pt-BR')

      get cars_path

      document = Nokogiri::HTML(response.body)
      public_link_source = document.at_css("[data-clipboard-target='source'][value*='/s/#{user.share_token}']")

      expect(public_link_source['value']).to include(public_share_path(user.share_token, locale: 'pt-BR'))
    end

    it 'renders active export actions before the first export' do
      get cars_path

      document = Nokogiri::HTML(response.body)
      export_buttons = document.css('.btn-export-action')

      expect(export_buttons.size).to eq(2)
      expect(response.body).to include(I18n.t('collection_exports.actions.generate', file_format: 'CSV'))
      expect(response.body).to include(I18n.t('collection_exports.actions.generate', file_format: 'PDF'))
    end

    it 'shows the last generation date for completed exports' do
      generated_at = Time.zone.local(2026, 1, 15, 10, 30)
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      create_completed_export('csv', generated_at)
      create_completed_export('pdf', generated_at)

      get cars_path

      expected_text = I18n.t('collection_exports.status.generated_at',
                             date: I18n.l(generated_at, format: :export_timestamp))

      expect(response.body).to include(expected_text)
      expect(response.body.scan(expected_text).size).to eq(2)
    end

    it 'marks the processing text so list view can show only the loading icon' do
      processing_car = create(:car, user: user, photo_processing_status: 'pending')
      processing_car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      processing_car.save!

      get cars_path

      expect(response.body).to include('car-photo-processing-label')
      expect(response.body).to include(I18n.t('cars.card.photo_processing'))
    end

    it 'renders brand and AI indicator as metadata pills in the same badge list' do
      allow(ImageUpscalerService).to receive(:upscale_needed?).and_return(true)
      ai_car = create(:car, user: user, brand: 'Mini GT', size: '1:64', color: 'blue', photo_upscale_strategy: 'ai')
      ai_car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      ai_car.save!

      get cars_path

      document = Nokogiri::HTML(response.body)
      card = document.at_css("#car_#{ai_car.id}")
      badge_list = card.at_css('.metadata-chip-list')

      expect(badge_list.at_css('.collection-brand-badge.metadata-chip-brand').text).to include('Mini GT')
      expect(badge_list.at_css('.metadata-chip.metadata-chip-scale').text).to include('1:64')
      expect(badge_list.at_css('.metadata-chip.metadata-chip-color').text).to include(I18n.t('colors.blue', locale: :en))
      expect(badge_list.at_css('.metadata-chip.metadata-chip-ai').text).to include(I18n.t('cars.show.photo_upscaled_by_ai'))
    end

    it 'does not show the autodetection AI upscaling notice when enabled and configured' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      get cars_path

      expect(response.body).not_to include('autodetection_skip_upscaler')
      expect(response.body).not_to include('data-autodetection-upload-target="upscalerControls"')
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

      it 'filters cars by scale' do
        car_matching.update!(size: '1:64')

        get cars_path, params: { q: '1:64' }

        expect(response.body).to include('Searchable Car')
        expect(response.body).not_to include('Other Car')
      end

      it 'does not search cars by color' do
        car_matching.update!(color: 'blue')

        get cars_path, params: { q: 'blue' }

        expect(response.body).not_to include('Searchable Car')
        expect(response.body).not_to include('Other Car')
      end

      it 'filters cars by year' do
        car_matching.update!(year: 1988)

        get cars_path, params: { q: '1988' }

        expect(response.body).to include('Searchable Car')
        expect(response.body).not_to include('Other Car')
      end

      it 'filters cars by scale, brand, year and color menu parameters' do
        car_matching.update!(brand: 'Mini GT', size: '1:64', year: 2024, color: 'blue')
        car_not_matching.update!(brand: 'Hot Wheels', size: '1:18', year: 2023, color: 'red')

        get cars_path, params: { brand: 'Mini GT', size: '1:64', year: '2024', color: 'blue' }

        expect(response.body).to include('Searchable Car')
        expect(response.body).not_to include('Other Car')
      end
    end
  end

  describe 'wishlist prefill' do
    it 'renders the new car form with compatible wishlist values' do
      wishlist_item = create(:wishlist_item, user: user, name: 'Wishlist Porsche', brand: 'Mini GT', scale: '1:64')

      get new_car_path, params: {
        wishlist_item_id: wishlist_item.id.to_s,
        car: WishlistItemToCarAttributesService.new(wishlist_item).to_params
      }

      expect(response).to be_successful
      expect(response.body).to include('Wishlist Porsche')
      expect(response.body).to include('Mini GT')
      expect(response.body).to include('name="wishlist_item_id"')

      document = Nokogiri::HTML(response.body)
      expect(document.at_css("button[name='commit_action'][value='create_another']")).to be_nil
    end

    it 'marks the wishlist item as purchased and links the created car' do
      wishlist_item = create(:wishlist_item, user: user, name: 'Wishlist Skyline', brand: 'Tomica', scale: '1:64')
      wishlist_item.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      wishlist_item.save!

      expect do
        post cars_path, params: {
          wishlist_item_id: wishlist_item.id.to_s,
          car: {
            name: wishlist_item.name,
            brand: wishlist_item.brand,
            size: wishlist_item.scale,
            observations: wishlist_item.observations
          }
        }
      end.to change(user.cars, :count).by(1)

      created_car = user.cars.desc(:created_at).first
      expect(wishlist_item.reload.status).to eq('purchased')
      expect(wishlist_item.car_id).to eq(created_car.id)
    end

    it 'updates the wishlist card when a wishlist item is added through turbo' do
      wishlist_item = create(:wishlist_item, user: user, name: 'Wishlist RX-7', brand: 'Tomica', scale: '1:64')

      expect do
        post cars_path,
             params: {
               wishlist_item_id: wishlist_item.id.to_s,
               car: {
                 name: wishlist_item.name,
                 brand: wishlist_item.brand,
                 size: wishlist_item.scale,
                 photo: fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
               }
             },
             as: :turbo_stream
      end.to change(user.cars, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream action="replace"')
      expect(response.body).to include("target=\"wishlist_item_#{wishlist_item.id}\"")
      expect(response.body).to include(I18n.t('wishlist_items.statuses.purchased'))
    end

    it 'does not create another car from an already added wishlist item' do
      wishlist_item = create(:wishlist_item, user: user, status: 'purchased')

      expect do
        post cars_path,
             params: {
               wishlist_item_id: wishlist_item.id.to_s,
               car: valid_attributes
             },
             as: :turbo_stream
      end.not_to change(user.cars, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('wishlist_items.flash.already_in_collection'))
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

    it 'does not reuse the latest brand and scale when opening a new item directly' do
      create(:car, user: user, brand: 'Hot Wheels', size: '1:64')

      get new_car_path

      document = Nokogiri::HTML(response.body)
      brand_field = document.at_css('#car_brand')
      selected_scale = document.at_css('#car_size option[selected]')

      expect(brand_field['value']).to be_blank
      expect(selected_scale).to be_nil
    end

    it 'renders a quick action to keep adding items' do
      get new_car_path

      document = Nokogiri::HTML(response.body)
      create_another_button = document.at_css("button[name='commit_action'][value='create_another']")

      expect(create_another_button).to be_present
      expect(create_another_button['value']).to eq('create_another')
      expect(create_another_button.text).to include(I18n.t('cars.form.create_another'))
      expect(create_another_button['data-disable-with']).to include(I18n.t('cars.form.create_another'))
    end

    it 'uses explicit new item params when they are present' do
      create(:car, user: user, brand: 'Hot Wheels', size: '1:64')

      get new_car_path, params: { car: { brand: 'Matchbox', size: '1:43' } }

      document = Nokogiri::HTML(response.body)
      brand_field = document.at_css('#car_brand')
      selected_scale = document.at_css('#car_size option[selected]')

      expect(brand_field['value']).to eq('Matchbox')
      expect(selected_scale['value']).to eq('1:43')
    end

    it 'renders scale and color options translated in the current locale' do
      get new_car_path

      document = Nokogiri::HTML(response.body)
      other_scale = document.at_css("#car_size option[value='Outra']")
      blue_color = document.at_css("#car_color option[value='blue']")

      expect(other_scale.text).to eq(I18n.t('scales.other', locale: :en))
      expect(blue_color.text).to eq(I18n.t('colors.blue', locale: :en))

      user.set(locale: 'pt-BR')

      get new_car_path

      document = Nokogiri::HTML(response.body)
      other_scale = document.at_css("#car_size option[value='Outra']")
      blue_color = document.at_css("#car_color option[value='blue']")

      expect(other_scale.text).to eq(I18n.t('scales.other', locale: :'pt-BR'))
      expect(blue_color.text).to eq(I18n.t('colors.blue', locale: :'pt-BR'))
    end

    it 'shows the AI upscaling notice when enabled and configured' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      get new_car_path

      expect(response.body).to include(
        I18n.t('cars.form.ai_upscaling_notice', minimum_side: ImageUpscalerService.default_minimum_side)
      )
    end

    it 'renders the per-record upscaler toggle' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      get new_car_path

      document = Nokogiri::HTML(response.body)

      expect(document.at_css('#car_skip_upscaler')).to be_present
      expect(document.at_css('.photo-dropzone #car_skip_upscaler')).to be_nil
      expect(document.at_css('.car-upscaler-toggle #car_skip_upscaler')).to be_present
      expect(document.at_css('#cropperModal.image-crop-modal')).to be_present
      expect(document.at_css('#cropperModal .image-crop-modal-frame')).to be_present
      expect(response.body).to include(I18n.t('cars.form.skip_upscaler'))
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

  def create_completed_export(format_type, generated_at)
    Tempfile.create(['export', ".#{format_type}"]) do |file|
      file.write(format_type == 'csv' ? 'Nome' : '%PDF-1.4')
      file.rewind

      export = CollectionExport.create!(
        user: user,
        format_type: format_type,
        status: 'completed',
        file: Rack::Test::UploadedFile.new(file.path, "application/#{format_type}")
      )
      export.set(updated_at: generated_at)
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
        expect do
          post cars_path, params: { car: valid_attributes }
        end.to change(Car, :count).by(1)

        expect(Car.last.photo).to be_present
      end

      it 'shows photo presence errors in the form' do
        attributes_without_photo = valid_attributes.except(:photo)

        expect do
          post cars_path, params: { car: attributes_without_photo }, as: :turbo_stream
        end.not_to change(Car, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t('cars.form.validation_error_title'))
        expect(response.body).to include(Car.human_attribute_name(:photo))
      end

      it 'shows all validation errors at once' do
        invalid_attributes = valid_attributes.except(:photo).merge(name: '')

        expect do
          post cars_path, params: { car: invalid_attributes }, as: :turbo_stream
        end.not_to change(Car, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(Car.human_attribute_name(:photo))
        expect(response.body).to include(Car.human_attribute_name(:name))
      end

      it 'shows field errors without repeating the field name inline' do
        invalid_attributes = valid_attributes.except(:photo).merge(name: '')

        post cars_path, params: { car: invalid_attributes }, as: :turbo_stream

        document = Nokogiri::HTML.fragment(response.body)
        name_error = document.at_css('.car_name .invalid-feedback')

        expect(name_error.text.squish).to eq(I18n.t('errors.messages.blank'))
      end

      it 'rejects non-numeric years' do
        post cars_path, params: { car: valid_attributes.merge(year: 'abcd') }, as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(Car.human_attribute_name(:year))

        document = Nokogiri::HTML.fragment(response.body)
        year_error = document.at_css('.car_year .invalid-feedback')

        expect(year_error.text.squish).to eq(I18n.t('errors.messages.not_a_number'))
      end

      it 'applies numeric mask only to the year field' do
        get new_car_path

        document = Nokogiri::HTML(response.body)
        year_input = document.at_css('#car_year')
        name_input = document.at_css('#car_name')

        expect(year_input['data-controller']).to eq('numeric-mask')
        expect(year_input['data-action']).to include('input->numeric-mask#sanitize')
        expect(name_input['data-controller']).not_to eq('numeric-mask')
      end

      it 'persists the per-record upscaler preference' do
        post cars_path, params: { car: valid_attributes.merge(skip_upscaler: '1') }

        expect(Car.last.skip_upscaler).to be true
      end

      it 'creates a car from a detected item and keeps AI upscale only on the car' do
        allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
        allow(YoloDetectionService).to receive(:classify_color).and_return(nil)
        upscaled_file = processed_temp_image(width: 420, height: 420, upscale_strategy: :ai)
        autodetection = create(:autodetection, :completed, user: user)
        detected_item = create(:detected_item, autodetection: autodetection, cropped_photo_upscale_strategy: nil,
                                               cropped_photo_variant: nil)

        expect(ImageUpscalerService).to receive(:upscale_if_needed)
          .with(anything, minimum_side: ImageUpscalerService.default_minimum_side, use_ai: true, local_fallback: false)
          .and_return(upscaled_file)

        perform_enqueued_jobs do
          post cars_path,
               params: {
                 detected_item_id: detected_item.id.to_s,
                 car: {
                   name: 'Verified car',
                   brand: 'Hot Wheels',
                   skip_upscaler: '0'
                 }
               },
               as: :turbo_stream
        end

        car = Car.last
        processed_item = detected_item.reload

        expect(car.detected_via_ai).to be true
        expect(car.original_photo).to be_present
        expect(car.enhanced_photo).to be_present
        expect(car.photo_upscale_strategy).to eq('ai')
        expect(car.photo_variant).to eq('ai')
        expect(processed_item.status).to eq('saved')
        expect(processed_item.cropped_photo_upscale_strategy).to be_nil
        expect(processed_item.cropped_photo_variant).to be_nil
        expect(processed_item.enhanced_cropped_photo).not_to be_present
      ensure
        begin
          upscaled_file&.close
          upscaled_file&.unlink
        rescue StandardError
          nil
        end
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
        allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
        attributes = valid_attributes.merge(size: '1:64', skip_upscaler: '1')

        expect do
          post cars_path,
               params: { car: attributes, commit_action: 'create_another' },
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
        expect(document.at_css('#car_brand')['value']).to eq(attributes[:brand])
        expect(document.at_css('#car_size option[selected]')['value']).to eq(attributes[:size])
        expect(document.at_css('#car_skip_upscaler')['checked']).to eq('checked')
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

    it 'shows the per-record upscaler toggle for a small existing photo when AI is enabled' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
      car.photo = uploaded_resized_fixture(width: 240, height: 240)
      car.save!

      get edit_car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      document = Nokogiri::HTML(response.body)
      toggle = document.at_css('.car-upscaler-toggle[data-photo-upload-target="upscalerToggle"]')

      expect(toggle).to be_present
      expect(toggle['class']).not_to include('d-none')
      expect(document.at_css('.car-ai-variant-comparison')).to be_present
      expect(document.at_css('.car-ai-variant-card.is-missing .car-ai-variant-question')).to be_present
      expect(document.at_css('#car_skip_upscaler')['checked']).to eq('checked')
      expect(response.body).to include(I18n.t('cars.form.skip_upscaler_existing'))
      expect(response.body).to include(I18n.t('cars.form.original_photo'))
      expect(response.body).to include(I18n.t('cars.form.ai_photo'))
    end

    it 'keeps the per-record upscaler toggle hidden when the existing photo already meets the minimum side' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
      car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.save!

      get edit_car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      document = Nokogiri::HTML(response.body)
      toggle = document.at_css('.car-upscaler-toggle')

      expect(toggle).to be_present
      expect(toggle['class']).to include('d-none')
    end

    it 'shows original and AI choices when saved variants exist after processing' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
      car.original_photo = uploaded_resized_fixture(width: 360, height: 360, filename: 'processed_original.jpg')
      car.enhanced_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.skip_upscaler = false
      car.save!

      get edit_car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      document = Nokogiri::HTML(response.body)
      toggle = document.at_css('.car-upscaler-toggle[data-photo-upload-target="upscalerToggle"]')

      expect(response).to be_successful
      expect(toggle).to be_present
      expect(toggle['class']).not_to include('d-none')
      expect(toggle['data-persist-visible']).to eq('true')
      expect(document.at_css('.car-ai-variant-comparison')).to be_present
      expect(document.css('.car-ai-variant-card').size).to eq(2)
      expect(document.at_css(".car-ai-variant-card.is-selected [alt=\"#{I18n.t('cars.form.ai_photo')}\"]")).to be_present
      expect(document.at_css('#car_skip_upscaler')['checked']).to be_nil
    end

    it 'uses the original photo and persisted crop coordinates for editing an AI-displayed car' do
      car.original_photo = uploaded_resized_fixture(width: 240, height: 240, filename: 'small_original.jpg')
      car.enhanced_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.photo_crop_x = 0.1
      car.photo_crop_y = 0.2
      car.photo_crop_w = 0.3
      car.photo_crop_h = 0.4
      car.save!

      get edit_car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      document = Nokogiri::HTML(response.body)
      existing_photo = document.at_css('[data-photo-upload-target="existingPhoto"]')

      expect(response).to be_successful
      expect(existing_photo['data-url']).to include(car.original_photo.url)
      expect(existing_photo['data-url']).not_to include(car.enhanced_photo.url)
      expect(document.at_css('#car_crop_x')['value']).to eq('0.1')
      expect(document.at_css('#car_crop_y')['value']).to eq('0.2')
      expect(document.at_css('#car_crop_w')['value']).to eq('0.3')
      expect(document.at_css('#car_crop_h')['value']).to eq('0.4')
    end

    it "redirects if trying to edit another user's car" do
      other_car = create(:car, user: other_user)
      get edit_car_path(other_car)
      expect(response).to redirect_to(cars_path)
      expect(flash[:alert]).to eq(I18n.t('errors.messages.page_not_found'))
    end
  end

  describe 'GET /show' do
    it 'renders the detail view inside the global modal frame' do
      updated_at = Time.zone.local(2026, 6, 11, 2, 22)
      car.update!(color: 'blue', size: '1:64')
      car.set(updated_at: updated_at)
      car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.original_photo = uploaded_resized_fixture(width: 240, height: 240, filename: 'small_original.jpg')
      car.enhanced_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.save!
      car.set(updated_at: updated_at)

      get car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('id="turboModal"')
      expect(response.body).to include(car.name)
      document = Nokogiri::HTML(response.body)
      delete_form = document.at_css("form[data-car-removal-car-id='#{car.id}']")
      delete_button = document.at_css("[data-car-removal-trigger][data-car-removal-car-id='#{car.id}']")
      edit_link = document.at_css("a[href='#{edit_car_path(car)}']")
      share_image_link = document.at_css("a[href='#{car_share_image_path(car)}']")

      expect(document.at_css('#turboModalLabel')).to be_nil
      expect(document.at_css('[data-controller*="photo-lightbox"]')).to be_present
      expect(document.at_css('.public-detail-photo[data-action="click->photo-lightbox#open"]')).to be_present
      expect(document.at_css('.photo-lightbox-overlay[data-photo-lightbox-target="overlay"]')).to be_present
      expect(response.body).not_to include('data-bs-target="#photoLightbox')
      expect(edit_link).to be_present
      expect(share_image_link).to be_present
      expect(share_image_link.text).to include(I18n.t('cars.show.share_image'))
      expect(delete_form['data-turbo-frame']).to be_nil
      expect(delete_form['data-turbo-confirm']).to be_nil
      expect(delete_button['data-car-removal-confirm-message']).to eq(I18n.t('items.delete_confirm'))
      expect(delete_button).to be_present
      expect(response.body).to include(I18n.t('activerecord.attributes.car.size'))
      expect(response.body).to include(I18n.t('activerecord.attributes.car.color'))
      expect(response.body).to include(I18n.t('activerecord.attributes.car.observations'))
      expect(response.body).to include(I18n.t('colors.blue', locale: :en))
      expect(response.body).to include('1:64')
      expect(response.body).to include(I18n.t('cars.show.photo_upscaled_by_ai'))
      expect(response.body).to include(I18n.t('cars.show.photo_upscaled_by_ai_tooltip'))
      expect(response.body).to include(I18n.l(car.created_at.to_date, format: :numeric))
      expect(response.body).to include(I18n.t('cars.show.updated_at', date: I18n.l(updated_at, format: :short)))
      expect(document.at_css('.public-detail-notes')).to be_present
      expect(document.css('.car-details-timestamp').size).to eq(2)
    end

    it 'shows the original photo action only when the displayed photo is the AI variant' do
      car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.original_photo = uploaded_resized_fixture(width: 240, height: 240, filename: 'small_original.jpg')
      car.enhanced_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.save!

      get car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      document = Nokogiri::HTML(response.body)
      original_toggle = document.at_css('[data-action="click->photo-variant-toggle#toggle"]')
      full_photo = document.at_css('[data-photo-variant-toggle-target="lightboxImage"]')

      expect(response.body).to include(I18n.t('cars.show.view_original_photo'))
      expect(response.body).to include(I18n.t('cars.show.photo_upscaled_by_ai'))
      expect(response.body).to include(I18n.t('cars.show.view_ai_photo'))
      expect(original_toggle).to be_present
      expect(original_toggle.name).to eq('button')
      expect(original_toggle['target']).to be_nil
      expect(full_photo).to be_present

      car.update!(photo_variant: 'original', photo_upscale_strategy: nil)

      get car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).not_to include(I18n.t('cars.show.view_original_photo'))
      expect(response.body).not_to include(I18n.t('cars.show.photo_upscaled_by_ai'))
    end

    it 'does not show AI actions when the original already meets the required size' do
      car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.original_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.save!

      get car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).not_to include(I18n.t('cars.show.view_original_photo'))
      expect(response.body).not_to include(I18n.t('cars.show.photo_upscaled_by_ai'))
      expect(response.body).to include(car.original_photo.url)
    end

    it 'shows only the original photo when account AI upscaling is disabled' do
      user.update!(ai_upscaling_enabled: false)
      car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.original_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.save!

      get car_path(car), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).not_to include(I18n.t('cars.show.view_original_photo'))
      expect(response.body).not_to include(I18n.t('cars.show.photo_upscaled_by_ai'))
      expect(response.body).to include(car.original_photo.url)
    end

    it 'shows aligned creation and update timestamps on the private detail page' do
      updated_at = Time.zone.local(2026, 6, 11, 2, 22)
      car.set(updated_at: updated_at)

      get car_path(car)

      expect(response).to be_successful
      expect(response.body).to include(I18n.t('cars.show.added_at', date: I18n.l(car.created_at.to_date, format: :numeric)))
      expect(response.body).to include(I18n.t('cars.show.updated_at', date: I18n.l(updated_at, format: :short)))

      document = Nokogiri::HTML(response.body)
      expect(document.css('.car-details-timestamp').size).to eq(2)
    end

    it 'subscribes to car detail updates for background photo processing' do
      get car_path(car)

      signed_stream = Turbo::StreamsChannel.signed_stream_name("cars_#{user.id}")
      document = Nokogiri::HTML(response.body)

      expect(response).to be_successful
      expect(response.body).to include(signed_stream)
      expect(document.at_css("#car_details_#{car.id}")).to be_present
    end

    it "does not show another user's car" do
      other_car = create(:car, user: other_user)

      get car_path(other_car)

      expect(response).to redirect_to(cars_path)
      expect(flash[:alert]).to eq(I18n.t('errors.messages.page_not_found'))
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
        expect(response.body).to include("turbo-stream action=\"replace\" target=\"car_showcase_details_#{car.id}\"")
        expect(response.body).to include("turbo-stream action=\"replace\" target=\"car_details_#{car.id}\"")
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include('flash_toasts')
      end

      it 'rerenders the modal form when turbo stream validation fails' do
        patch car_path(car),
              params: { car: { name: '', crop_x: '0.1', crop_y: '0.2', crop_w: '0.3', crop_h: '0.4' } },
              as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include('id="turboModal"')
        expect(response.body).to include("edit_car_#{car.id}")
        expect(response.body).to include('value="0.1"')
        expect(response.body).to include('value="0.2"')
        expect(response.body).to include('value="0.3"')
        expect(response.body).to include('value="0.4"')
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

  describe 'PATCH /toggle_bulk_ai_upscaling' do
    it 'toggles the bulk AI upscaling preference and enqueues the coordinator' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)

      expect do
        patch toggle_bulk_ai_upscaling_cars_path, as: :turbo_stream
      end.to have_enqueued_job(BulkAiUpscaleJob).with(user.id.to_s)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream action="update" target="ai_upscaling_settings_toggle"')
      expect(user.reload.bulk_ai_upscaling_enabled).to be true
    end

    it 'does not toggle bulk processing when global AI upscaling is disabled' do
      allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
      user.update!(ai_upscaling_enabled: false)

      patch toggle_bulk_ai_upscaling_cars_path

      expect(response).to redirect_to(edit_user_registration_path)
      expect(user.reload.bulk_ai_upscaling_enabled).to be false
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

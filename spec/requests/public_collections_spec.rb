# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public Collections', type: :request do
  let(:user) { create(:user, sharing_enabled: true, share_token: 'test-token') }
  let!(:car) { create(:car, user: user, name: 'Public Car') }

  describe 'GET /s/:share_token' do
    it 'allows access without login' do
      get public_share_path(user.share_token)
      expect(response).to have_http_status(:success)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('h1').text).to include(I18n.t('public_collections.index.title', name: user.name))
      expect(response.body).to include('Public Car')
    end

    it 'renders the public collection in the URL locale' do
      get public_share_path(user.share_token), params: { locale: 'pt-BR' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t('public_collections.index.title', name: user.name, locale: :'pt-BR'))
      expect(response.body).to include(I18n.t('public_collections.index.cataloged_count', locale: :'pt-BR'))
    end

    it 'renders the cataloged count with theme-safe contrast classes' do
      get public_share_path(user.share_token)

      document = Nokogiri::HTML(response.body)
      stat = document.at_css('.public-collection-stat')
      stat_number = stat.at_css('.public-collection-stat-number')
      stat_label = stat.at_css('.public-collection-stat-label')

      expect(stat).to be_present
      expect(stat_number.text.squish).to eq('1')
      expect(stat_label.text.squish).to include(I18n.t('public_collections.index.cataloged_count'))
      expect(stat['class']).not_to include('bg-white')
      expect(stat_number['class']).not_to include('text-white')
      expect(stat_label['class']).not_to include('text-white')
    end

    it 'uses the same search placeholder as the private catalog' do
      get public_share_path(user.share_token)

      document = Nokogiri::HTML(response.body)
      search_input = document.at_css('input[name="q"]')

      expect(search_input['placeholder']).to eq(I18n.t('cars.index.search_placeholder'))
    end

    it 'filters public cars by scale, color and year' do
      car.update!(name: 'Filtered Public Car', size: '1:64', color: 'Azul', year: 1988)
      create(:car, user: user, name: 'Other Public Car', size: '1:18', color: 'Vermelho', year: 1970)

      get public_share_path(user.share_token), params: { q: '1:64' }
      expect(response.body).to include('Filtered Public Car')
      expect(response.body).not_to include('Other Public Car')

      get public_share_path(user.share_token), params: { q: 'azul' }
      expect(response.body).to include('Filtered Public Car')
      expect(response.body).not_to include('Other Public Car')

      get public_share_path(user.share_token), params: { q: '1988' }
      expect(response.body).to include('Filtered Public Car')
      expect(response.body).not_to include('Other Public Car')
    end

    it 'renders public view modes with a premium gallery carousel and opens public cards in a modal' do
      car.update!(
        brand: 'Porsche',
        year: 2024,
        size: '1:64',
        color: 'Azul',
        tags: %w[Premium Destaque],
        observations: 'Miniatura com pintura especial e caixa preservada.',
        photo: fixture_file_upload(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
      )

      get public_share_path(user.share_token)

      document = Nokogiri::HTML(response.body)
      view_toggle = document.at_css('[data-view-toggle-storage-key-value="public_collection_view_preference"]')
      carousel = document.at_css('#publicCollectionCarousel')
      gallery_button = document.at_css('[data-action="click->view-toggle#setGallery"]')
      localized_car_path = public_share_car_path(user.share_token, car, locale: 'en')
      public_card_link = document.at_css("#cars_grid_inner a[href='#{localized_car_path}']")
      gallery_slide_link = document.at_css(".public-gallery-slide a[href='#{localized_car_path}']")

      expect(view_toggle['data-view-toggle-storage-key-value']).to eq('public_collection_view_preference')
      expect(carousel).to be_present
      expect(gallery_button).to be_present
      expect(public_card_link['data-turbo-frame']).to eq('modal')
      expect(gallery_slide_link).to be_nil
      expect(document.at_css('.public-gallery-slide .public-gallery-feature')).to be_present
      expect(document.at_css('.public-gallery-thumbnails.carousel-indicators')).to be_present
      expect(document.at_css('.public-gallery-photo img')).to be_present
      expect(document.at_css('.public-gallery-lightbox-button[data-action="click->photo-lightbox#open"]')).to be_present
      expect(document.at_css('.public-gallery-slide[data-controller="photo-lightbox"]')).to be_present
      expect(document.at_css('.public-gallery-slide .photo-lightbox-overlay')).to be_present
      expect(response.body).to include('Porsche')
      expect(response.body).to include('2024')
      expect(response.body).to include('1:64')
      expect(response.body).to include('Azul')
      expect(response.body).to include('Premium, Destaque')
      expect(response.body).to include('Miniatura com pintura especial')
      expect(document.at_css('.public-gallery-thumbnails')).to be_present
      expect(response.body).to include('public-gallery-shell')
      expect(response.body).to include('data-search-form-target="spinner"')
    end

    it 'paginates the public collection' do
      create_list(:car, 20, user: user)

      get public_share_path(user.share_token), params: { locale: 'pt-BR' }

      expect(response).to have_http_status(:success)
      expect(response.body.scan('id="cars_sentinel"').size).to eq(1)
      document = Nokogiri::HTML(response.body)
      sentinel_url = document.at_css('#cars_sentinel')['data-infinite-scroll-url-value']
      expect(sentinel_url).to include('locale=pt-BR')

      get public_share_path(user.share_token), params: { page: 2, locale: 'pt-BR' }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).to include('turbo-stream action="append" target="public_gallery_slides"')
      expect(response.body).to include('turbo-stream action="append" target="public_gallery_thumbnails"')
      expect(response.body).to include('data-bs-slide-to="20"')
      expect(response.body).not_to include('public-gallery-slide active')
      expect(response.body).not_to include('turbo-stream action="replace" target="cars_sentinel"')
      expect(response.body).to include('turbo-stream action="remove" target="cars_sentinel"')
    end

    it 'redirects to landing page if sharing is disabled' do
      user.update(sharing_enabled: false)
      get public_share_path(user.share_token)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t('errors.messages.page_not_found'))
    end

    it 'redirects to landing page for invalid token' do
      get public_share_path('invalid-token')
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t('errors.messages.page_not_found'))
    end
  end

  describe 'GET /s/:share_token/car/:id' do
    it 'allows access to car details without login' do
      get public_share_car_path(user.share_token, car.id), params: { locale: 'pt-BR' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Public Car')
      expect(response.body).to include(public_share_path(user.share_token, locale: 'pt-BR'))
    end

    it 'renders public car details inside the global modal frame' do
      car.update!(
        color: 'Azul',
        size: '1:64',
        observations: 'Versão especial com pintura azul e caixa preservada.'
      )
      car.photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.original_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.enhanced_photo = fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      car.photo_variant = 'ai'
      car.photo_upscale_strategy = 'ai'
      car.save!

      get public_share_car_path(user.share_token, car.id), headers: { 'Turbo-Frame' => 'modal' }

      document = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('id="turboModal"')
      expect(response.body).to include('turbo-public-car-modal')
      expect(response.body).to include('Public Car')
      expect(document.at_css('#turboModalLabel')).to be_nil
      expect(document.at_css('[data-controller="photo-lightbox"]')).to be_present
      expect(document.at_css('.public-detail-photo[data-action="click->photo-lightbox#open"]')).to be_present
      expect(document.at_css('.photo-lightbox-overlay[data-photo-lightbox-target="overlay"]')).to be_present
      expect(response.body).not_to include('data-bs-target="#photoLightbox')
      expect(document.at_css("a[href='#{edit_car_path(car)}']")).to be_nil
      expect(document.at_css("[data-car-removal-trigger][data-car-removal-car-id='#{car.id}']")).to be_nil
      expect(response.body).to include(I18n.t('activerecord.attributes.car.color'))
      expect(response.body).not_to include(I18n.t('cars.show.view_original_photo'))
      expect(response.body).to include('Azul')
      expect(response.body).to include('1:64')
      expect(response.body).to include(I18n.l(car.created_at.to_date, format: :numeric))
      expect(response.body).not_to include(I18n.t('cars.show.updated_at', date: I18n.l(car.updated_at, format: :short)))
      expect(document.at_css('.public-detail-notes')).to be_present
      expect(document.css('.car-details-timestamp').size).to eq(1)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WishlistItems', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /wishlist' do
    it 'renders only the current user wishlist items' do
      own_item = create(:wishlist_item, user: user, name: 'Visible wish')
      create(:wishlist_item, user: other_user, name: 'Private wish')

      get wishlist_items_path

      expect(response).to be_successful
      expect(response.body).to include(own_item.name)
      expect(response.body).to include(ERB::Util.html_escape(new_car_path(wishlist_item_id: own_item.id.to_s, car: WishlistItemToCarAttributesService.new(own_item).to_params)))
      expect(response.body).not_to include('Private wish')
    end

    it 'renders background export controls for CSV and PDF' do
      get wishlist_items_path

      expect(response.body).to include('wishlist_export_csv_status_container')
      expect(response.body).to include('wishlist_export_pdf_status_container')
      expect(response.body).to include('export_type')
      expect(response.body).to include('wishlist')
    end

    it 'renders live search and compact filter controls' do
      get wishlist_items_path

      expect(response.body).to include('data-controller="search-form"')
      expect(response.body).to include('data-turbo-frame="wishlist_grid"')
      expect(response.body).to include('data-action="input-&gt;search-form#submit"')
      expect(response.body).to include('id="wishlist_grid"')
      expect(response.body).to include(I18n.t('wishlist_items.index.filter_menu'))
    end

    it 'renders brand, scale and status as metadata pills in the same badge list' do
      item = create(:wishlist_item, user: user, name: 'Wishlist RX-7', brand: 'Mini GT', scale: '1:64')

      get wishlist_items_path

      document = Nokogiri::HTML(response.body)
      card = document.at_css("##{ActionView::RecordIdentifier.dom_id(item)}")
      badge_list = card.at_css('.metadata-chip-list')

      expect(badge_list.at_css('.collection-brand-badge.metadata-chip-brand').text).to include('Mini GT')
      expect(badge_list.at_css('.metadata-chip.metadata-chip-scale').text).to include('1:64')
      expect(badge_list.text).to include(item.status_label)
    end

    it 'filters by status, priority, brand, scale and query without searching notes' do
      matching = create(
        :wishlist_item,
        user: user,
        name: 'Blue Porsche',
        brand: 'Mini GT',
        scale: '1:64',
        status: 'reserved',
        priority: 'high',
        observations: 'Hidden clue'
      )
      create(:wishlist_item, user: user, name: 'Red Ferrari', brand: 'Hot Wheels',
                             scale: '1:18', status: 'wanted', priority: 'low')
      create(:wishlist_item, user: user, name: 'Silent Skyline', brand: 'Mini GT',
                             scale: '1:64', status: 'reserved', priority: 'high',
                             observations: 'Porsche')

      get wishlist_items_path,
          params: { q: 'Porsche', brand: 'Mini GT', scale: '1:64', status: 'reserved', priority: 'high' }

      expect(response.body).to include(matching.name)
      expect(response.body).not_to include('Red Ferrari')
      expect(response.body).not_to include('Silent Skyline')
    end
  end

  describe 'POST /collection_exports for wishlist' do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it 'creates a pending wishlist export and enqueues the export job' do
      expect do
        post collection_exports_path(format_type: 'csv'),
             params: { export_type: 'wishlist' },
             as: :turbo_stream
      end.to have_enqueued_job(ExportCollectionJob)

      export = user.collection_exports.last
      expect(export.export_type).to eq('wishlist')
      expect(export.format_type).to eq('csv')
      expect(response.body).to include('wishlist_export_csv_status_container')
    end
  end

  describe 'PATCH /wishlist/toggle_sharing' do
    it 'enables wishlist sharing and creates a public token' do
      patch toggle_sharing_wishlist_items_path

      expect(response).to redirect_to(wishlist_items_path)
      expect(user.reload.wishlist_sharing_enabled).to be true
      expect(user.wishlist_share_token).to be_present
    end

    it 'disables wishlist sharing without removing the token' do
      user.update!(wishlist_sharing_enabled: true)
      token = user.wishlist_share_token

      patch toggle_sharing_wishlist_items_path

      expect(user.reload.wishlist_sharing_enabled).to be false
      expect(user.wishlist_share_token).to eq(token)
    end
  end

  describe 'POST /wishlist' do
    it 'creates a wishlist item scoped to the current user' do
      expect do
        post wishlist_items_path, params: {
          wishlist_item: {
            name: 'Nissan Skyline',
            brand: 'Tomica',
            scale: '1:64',
            status: 'wanted',
            priority: 'dream',
            target_price_cents: 12_990,
            reference_url: 'https://example.com/skyline'
          }
        }
      end.to change(user.wishlist_items, :count).by(1)

      expect(response).to redirect_to(wishlist_items_path)
      expect(user.wishlist_items.last.name).to eq('Nissan Skyline')
      expect(user.wishlist_items.last.target_price_cents).to be_nil
    end

    it 'does not create with unsafe reference URL' do
      expect do
        post wishlist_items_path, params: {
          wishlist_item: {
            name: 'Unsafe URL',
            status: 'wanted',
            priority: 'medium',
            reference_url: 'javascript:alert(1)'
          }
        }
      end.not_to change(user.wishlist_items, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'renders validation errors inside the modal for turbo requests' do
      post wishlist_items_path,
           params: { wishlist_item: { name: '', status: 'wanted', priority: 'medium' } },
           as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('turbo-stream action="update" target="modal"')
      expect(response.body).to include(I18n.t('wishlist_items.form.validation_error_title'))
    end
  end

  describe 'PATCH /wishlist/:id' do
    it 'updates a wishlist item owned by the current user' do
      item = create(:wishlist_item, user: user)

      patch wishlist_item_path(item), params: {
        wishlist_item: {
          name: 'Updated wish',
          brand: item.brand,
          scale: item.scale,
          status: 'reserved',
          priority: 'high'
        }
      }

      expect(response).to redirect_to(wishlist_items_path)
      expect(item.reload.status).to eq('reserved')
      expect(item.name).to eq('Updated wish')
    end

    it 'does not update another user wishlist item' do
      item = create(:wishlist_item, user: other_user)

      patch wishlist_item_path(item), params: {
        wishlist_item: {
          name: 'Intrusion',
          status: 'purchased',
          priority: 'high'
        }
      }

      expect(item.reload.name).not_to eq('Intrusion')
      expect(item.status).to eq('wanted')
    end
  end

  describe 'GET /wishlist/:id' do
    it 'renders item details in a modal for turbo frame requests' do
      item = create(:wishlist_item, user: user, name: 'Modal wish', reference_url: 'https://example.com/reference')

      get wishlist_item_path(item), headers: { 'Turbo-Frame' => 'modal' }

      expect(response).to be_successful
      expect(response.body).to include('turboModal')
      expect(response.body).to include('Modal wish')
      expect(response.body).to include('https://example.com/reference')
      expect(response.body).to include(I18n.t('wishlist_items.actions.share_item_image'))
      expect(response.body).to include(ERB::Util.html_escape(new_car_path(wishlist_item_id: item.id.to_s, car: WishlistItemToCarAttributesService.new(item).to_params)))
      expect(response.body).to include('data-turbo-frame="modal"')
      expect(response.body).not_to include(I18n.t('wishlist_items.actions.open_reference'))
    end
  end

  describe 'DELETE /wishlist/:id' do
    it 'destroys a wishlist item owned by the current user' do
      item = create(:wishlist_item, user: user)

      expect do
        delete wishlist_item_path(item)
      end.to change(user.wishlist_items, :count).by(-1)

      expect(response).to redirect_to(wishlist_items_path)
    end
  end

  describe 'POST /wishlist/:id/add_to_collection' do
    it 'redirects to a prefilled new car form for the current user item' do
      item = create(:wishlist_item, user: user, name: 'Mazda RX-7', brand: 'Mini GT', scale: '1:64')

      post add_to_collection_wishlist_item_path(item)

      expect(response).to redirect_to(
        new_car_path(
          wishlist_item_id: item.id.to_s,
          car: {
            name: 'Mazda RX-7',
            brand: 'Mini GT',
            size: '1:64',
            observations: item.observations,
            remote_photo_url: item.photo.url
          }.compact_blank
        )
      )
    end

    it 'does not redirect another user wishlist item into the car form' do
      item = create(:wishlist_item, user: other_user)

      post add_to_collection_wishlist_item_path(item)

      expect(response).not_to redirect_to(/wishlist_item_id=#{item.id}/)
    end
  end
end

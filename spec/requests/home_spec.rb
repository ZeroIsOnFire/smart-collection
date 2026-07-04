# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home', type: :request do
  describe 'GET /' do
    it 'presents the wishlist as part of the catalog workflow' do
      get root_path

      expect(response).to be_successful
      expect(response.body).to include(I18n.t('home.hero.badge'))
      expect(response.body).to include(I18n.t('home.features.cards').third[:title])
      expect(response.body).to include(I18n.t('home.cta.items').second)
    end
  end
end

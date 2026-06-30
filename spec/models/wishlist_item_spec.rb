# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WishlistItem, type: :model do
  let(:wishlist_item) { build(:wishlist_item) }

  it 'is valid with valid attributes' do
    expect(wishlist_item).to be_valid
  end

  it 'requires a name' do
    wishlist_item.name = nil

    expect(wishlist_item).not_to be_valid
    expect(wishlist_item.errors[:name]).to include(I18n.t('errors.messages.blank'))
  end

  it 'accepts only fixed statuses' do
    wishlist_item.status = 'archived'

    expect(wishlist_item).not_to be_valid
  end

  it 'accepts only fixed priorities' do
    wishlist_item.priority = 'urgent'

    expect(wishlist_item).not_to be_valid
  end

  it 'rejects non-http reference URLs' do
    wishlist_item.reference_url = 'javascript:alert(1)'

    expect(wishlist_item).not_to be_valid
    expect(wishlist_item.errors[:reference_url]).to include(I18n.t('errors.messages.invalid'))
  end

  it 'allows blank optional fields' do
    wishlist_item.brand = nil
    wishlist_item.scale = nil
    wishlist_item.reference_url = nil
    wishlist_item.target_price_cents = nil

    expect(wishlist_item).to be_valid
  end
end

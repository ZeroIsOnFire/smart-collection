# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WishlistItemToCarAttributesService do
  it 'maps compatible wishlist fields to car attributes' do
    wishlist_item = build(:wishlist_item, name: 'Mazda RX-7', brand: 'Mini GT', scale: '1:64',
                                          observations: 'Wanted variant.')

    attributes = described_class.new(wishlist_item).to_params

    expect(attributes).to include(
      name: 'Mazda RX-7',
      brand: 'Mini GT',
      size: '1:64',
      observations: 'Wanted variant.'
    )
  end
end

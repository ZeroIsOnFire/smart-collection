# frozen_string_literal: true

FactoryBot.define do
  factory :wishlist_item do
    name { 'Porsche 911 Treasure Hunt' }
    brand { 'Hot Wheels' }
    scale { '1:64' }
    observations { 'Keep an eye on local stores.' }
    priority { 'medium' }
    status { 'wanted' }
    target_price_cents { 4990 }
    reference_url { 'https://example.com/listing' }
    association :user
  end
end

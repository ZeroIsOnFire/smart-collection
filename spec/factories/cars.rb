# frozen_string_literal: true

FactoryBot.define do
  factory :car do
    name { 'Volkswagen Fusca' }
    brand { 'Hot Wheels' }
    tags { %w[classic vintage] }
    observations { 'Carro de colecionador, pintura original.' }
    size { 'Small' }
    year { 1970 }
    association :user
  end
end

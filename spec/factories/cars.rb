FactoryBot.define do
  factory :car do
    name { 'Fusca' }
    brand { 'Hot Wheels' }
    manufacturer { 'Volkswagen' }
    observations { 'Carro de colecionador, pintura original.' }
    size { 'Small' }
    year { 1970 }
    association :user
  end
end

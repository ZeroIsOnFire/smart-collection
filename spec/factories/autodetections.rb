FactoryBot.define do
  factory :autodetection do
    user
    status { 'pending' }
    photo { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') }

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :error do
      status { 'error' }
      error_message { 'Timeout error' }
    end
  end
end

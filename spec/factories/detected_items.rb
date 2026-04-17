FactoryBot.define do
  factory :detected_item do
    autodetection
    label { "Matchbox Porsche" }
    status { "pending" }
    position_data { 
      { 
        "score" => 0.95, 
        "vertices" => [
          { "x" => 0.1, "y" => 0.1 },
          { "x" => 0.4, "y" => 0.1 },
          { "x" => 0.4, "y" => 0.4 },
          { "x" => 0.1, "y" => 0.4 }
        ] 
      } 
    }
    
    cropped_photo { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg') }
  end
end

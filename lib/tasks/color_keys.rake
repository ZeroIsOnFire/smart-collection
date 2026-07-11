# frozen_string_literal: true

namespace :data do
  desc 'Normaliza as chaves legadas de cores para inglês'
  task normalize_color_keys: :environment do
    [Car, DetectedItem].each do |model|
      Car::LEGACY_COLOR_KEYS.each do |legacy_key, normalized_key|
        result = model.collection.update_many(
          { color: legacy_key },
          { '$set' => { color: normalized_key } }
        )

        puts "#{model.name}: #{legacy_key} -> #{normalized_key} (#{result.modified_count})"
      end
    end
  end
end

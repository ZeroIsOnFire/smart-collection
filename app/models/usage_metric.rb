# frozen_string_literal: true

class UsageMetric
  include Mongoid::Document
  include Mongoid::Timestamps

  field :key, type: String
  field :count, type: Integer, default: 0

  index({ key: 1 }, { unique: true, background: true })

  validates :key, presence: true, uniqueness: true
  validates :count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.record!(key, by: 1)
    collection.find_one_and_update(
      { key: key.to_s },
      {
        '$inc' => { count: by.to_i },
        '$setOnInsert' => { created_at: Time.current },
        '$set' => { updated_at: Time.current }
      },
      upsert: true,
      return_document: :after
    )
  rescue StandardError => e
    Rails.logger.error "UsageMetric increment failed for #{key}: #{e.message}"
    nil
  end

  def self.values_for(keys)
    metrics = where(:key.in => keys.map(&:to_s)).pluck(:key, :count).to_h

    keys.index_with { |key| metrics.fetch(key.to_s, 0).to_i }
  end
end

# frozen_string_literal: true

class ShareImageCacheService
  DEFAULT_EXPIRES_IN = 30.days

  def self.fetch(record:, kind:, cache: Rails.cache, expires_in: DEFAULT_EXPIRES_IN)
    cache.fetch(cache_key(record:, kind:), expires_in:) do
      ShareImageService.new(record:, kind:).generate
    end
  end

  def self.clear(record:, kind:, cache: Rails.cache)
    cache.delete(cache_key(record:, kind:))
  end

  def self.cache_key(record:, kind:)
    ['share_images', kind, record.class.name, record.id].join(':')
  end
end

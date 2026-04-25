# frozen_string_literal: true

require 'kaminari/mongoid'

Kaminari.configure do |config|
  config.default_per_page = 20
  config.max_per_page = 100
  config.window = 2
end

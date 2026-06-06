# frozen_string_literal: true

module ProtectedMongoidPurge
  TEST_DATABASE_PATTERN = /(?:^|[_-])test(?:$|[_-])/i

  class UnsafeDatabaseError < StandardError; end

  module_function

  def call(mongoid: Mongoid, rails_env: Rails.env)
    database_name = mongoid.default_client.database.name

    unless rails_env.test? && database_name.match?(TEST_DATABASE_PATTERN)
      raise UnsafeDatabaseError,
            "Refusing to purge MongoDB database '#{database_name}' while Rails.env is '#{rails_env}'."
    end

    mongoid.purge!
  end
end

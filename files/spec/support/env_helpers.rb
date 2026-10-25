# frozen_string_literal: true

module EnvHelpers
  def with_env(values)
    previous = values.keys.index_with { |key| ENV.fetch(key, nil) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous&.each { |key, value| ENV[key] = value }
  end
end

RSpec.configure do |config|
  config.include EnvHelpers
end

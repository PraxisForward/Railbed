# typed: strict
# frozen_string_literal: true

module Credentials
  extend T::Sig

  sig { params(keys: Symbol).returns(T.nilable(String)) }
  def self.dig(*keys)
    ENV[keys.join("_").upcase].presence || scalar(Rails.application.credentials.dig(*keys))
  end

  sig { params(value: T.untyped).returns(T.nilable(String)) }
  def self.scalar(value)
    value.to_s if value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
  end
  private_class_method :scalar
end

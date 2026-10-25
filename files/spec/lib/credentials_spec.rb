# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credentials do
  around { |example| with_env("EXAMPLE_API_KEY" => nil) { example.run } }

  it "reads the key path from this environment's credentials" do
    stub_credentials("example:\n  api_key: from-credentials\n")

    expect(described_class.dig(:example, :api_key)).to eq("from-credentials")
  end

  it "prefers the upcased, underscore-joined ENV name over credentials" do
    stub_credentials("example:\n  api_key: from-credentials\n")

    value = with_env("EXAMPLE_API_KEY" => "from-env") { described_class.dig(:example, :api_key) }

    expect(value).to eq("from-env")
  end

  it "falls through a blank ENV value to credentials" do
    stub_credentials("example:\n  api_key: from-credentials\n")

    value = with_env("EXAMPLE_API_KEY" => " ") { described_class.dig(:example, :api_key) }

    expect(value).to eq("from-credentials")
  end

  it "returns nil when neither source has the key" do
    stub_credentials

    expect(described_class.dig(:example, :api_key)).to be_nil
  end

  it "stringifies a numeric credential" do
    stub_credentials("example:\n  api_key: 12345\n")

    expect(described_class.dig(:example, :api_key)).to eq("12345")
  end

  it "reads an unquoted true as the string true" do
    stub_credentials("example:\n  api_key: true\n")

    expect(described_class.dig(:example, :api_key)).to eq("true")
  end

  it "reads an unquoted false as the string false" do
    stub_credentials("example:\n  api_key: false\n")

    expect(described_class.dig(:example, :api_key)).to eq("false")
  end

  it "returns nil for a nested hash under the key path" do
    stub_credentials("example:\n  api_key:\n    value: misindented\n")

    expect(described_class.dig(:example, :api_key)).to be_nil
  end

  it "returns nil for a list under the key path" do
    stub_credentials("example:\n  api_key:\n    - first\n")

    expect(described_class.dig(:example, :api_key)).to be_nil
  end

  it "returns nil when the credentials file and key are absent" do
    stub_missing_credentials

    expect(described_class.dig(:example, :api_key)).to be_nil
  end

  it "is loaded by the once autoloader, so initializers can call it at boot" do
    expect(Rails.autoloaders.once.cpath_expected_at(Rails.root.join("lib/credentials.rb"))).to eq("Credentials")
  end

  it "never reads the checkout's credentials files from a spec" do
    expect(Rails.application.credentials.content_path.to_s).not_to start_with(Rails.root.join("config").to_s)
  end
end

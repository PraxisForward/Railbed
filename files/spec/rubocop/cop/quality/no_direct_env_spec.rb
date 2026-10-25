# frozen_string_literal: true

require "rubocop"
require_relative "../../../../lib/rubocop/cop/quality/no_direct_env"

RSpec.describe RuboCop::Cop::Quality::NoDirectEnv do
  let(:config) { RuboCop::Config.new("Quality/NoDirectEnv" => { "Enabled" => true }) }
  let(:cop) { described_class.new(config) }

  [
    'ENV["EXAMPLE_API_KEY"]',
    'ENV.fetch("EXAMPLE_API_KEY", nil)',
    "ENV.to_h",
    'ENV.key?("EXAMPLE_API_KEY")',
    'ENV.slice("EXAMPLE_API_KEY")',
    'ENV["EXAMPLE_API_KEY"] = "key"',
    'helper(ENV)',
    '::ENV["EXAMPLE_API_KEY"]'
  ].each do |source|
    it "reports #{source}" do
      expect(investigate(source)).to eq([ "Read settings through Credentials.dig instead of ENV." ])
    end
  end

  it "allows the credentials accessor and other constants named ENV" do
    expect(investigate("Credentials.dig(:example, :api_key)\nSettings::ENV.fetch(:x)\n")).to be_empty
  end

  def investigate(source)
    processed_source = RuboCop::ProcessedSource.new(source, RuboCop::TargetRuby::DEFAULT_VERSION)
    RuboCop::Cop::Team.new([ cop ], config, raise_error: true).investigate(processed_source).offenses.map(&:message)
  end
end

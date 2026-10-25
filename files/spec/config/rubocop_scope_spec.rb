# frozen_string_literal: true

require "rails_helper"
require "rubocop"

RSpec.describe "RuboCop scope" do
  subject(:cop_config) { config.fetch("Quality/PreferBarewordReaders") }

  let(:config) { RuboCop::ConfigLoader.load_file(Rails.root.join(".rubocop.yml")) }

  it "keeps bareword readers enforced" do
    expect(cop_config.fetch("Enabled")).to be(true)
  end

  it "allows Rails presentation layers to use framework-facing instance variables" do
    expect(cop_config.fetch("Exclude")).to contain_exactly(
      Rails.root.join("app/controllers/**/*").to_s,
      Rails.root.join("app/mailers/**/*").to_s,
      Rails.root.join("app/views/**/*").to_s
    )
  end

  describe "Quality/NoDirectEnv" do
    let(:probe_paths) do
      %w[
        app/models/probe.rb
        lib/example/probe.rb
        config/initializers/probe.rb
        lib/credentials.rb
        config/puma.rb
        spec/probe_spec.rb
      ]
    end

    it "keeps direct ENV reads out of app, lib, and initializers, except in the credentials accessor" do
      cop = RuboCop::Cop::Quality::NoDirectEnv.new(config)

      expect(probe_paths.select { |path| cop.relevant_file?(Rails.root.join(path).to_s) })
        .to eq(%w[app/models/probe.rb lib/example/probe.rb config/initializers/probe.rb])
    end
  end
end

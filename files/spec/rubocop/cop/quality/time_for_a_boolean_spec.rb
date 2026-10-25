# frozen_string_literal: true

require "rubocop"
require_relative "../../../../lib/rubocop/cop/quality/time_for_a_boolean"

RSpec.describe RuboCop::Cop::Quality::TimeForABoolean do
  subject(:offenses) { investigate(source) }

  let(:config) { RuboCop::Config.new("Quality/TimeForABoolean" => { "Enabled" => true }) }
  let(:cop) { described_class.new(config) }

  [
    "t.boolean :active",
    "t.column :active, :boolean",
    "add_column :users, :active, :boolean",
    "change_column :users, :active, :boolean"
  ].each do |statement|
    context "with #{statement}" do
      let(:source) { statement }

      it "reports the boolean column" do
        expect(offenses.map(&:message)).to contain_exactly(
          "Use a timestamp column and `time_for_a_boolean` instead of a boolean column."
        )
      end
    end
  end

  context "with a timestamp column" do
    let(:source) { "t.datetime :active_at" }

    it "does not report an offense" do
      expect(offenses).to be_empty
    end
  end

  def investigate(source)
    processed_source = RuboCop::ProcessedSource.new(source, RuboCop::TargetRuby::DEFAULT_VERSION)
    RuboCop::Cop::Team.new([ cop ], config, raise_error: true).investigate(processed_source).offenses
  end
end

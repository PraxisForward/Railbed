# frozen_string_literal: true

require "rubocop"
require_relative "../../../../lib/rubocop/cop/quality/one_element_per_line"

RSpec.describe RuboCop::Cop::Quality::OneElementPerLine do
  let(:config) { RuboCop::Config.new("Quality/OneElementPerLine" => { "Enabled" => true }) }
  let(:cop) { described_class.new(config) }

  it "reports keyword arguments that share a line after the call breaks" do
    source = <<~RUBY
      expect(parse).to have_attributes(
        client_id: "client-id", client_secret: "client-secret", host: "app.example.test"
      )
    RUBY

    expect(investigate(source)).to eq([
      [ 2, "Put each argument on its own line once the call breaks after its opening bracket." ],
      [ 2, "Put each argument on its own line once the call breaks after its opening bracket." ]
    ])
  end

  it "reports positional arguments and hash keys that share a line after the bracket breaks" do
    source = <<~RUBY
      call(
        1, 2
      )
      settings = {
        a: 1, **defaults
      }
    RUBY

    expect(investigate(source)).to eq([
      [ 2, "Put each argument on its own line once the call breaks after its opening bracket." ],
      [ 5, "Put each key on its own line once the hash breaks after its opening brace." ]
    ])
  end

  it "moves each element onto its own line at the first element's indentation" do
    source = <<~RUBY
      have_attributes(
        client_id: "client-id", client_secret: "client-secret", host: "app.example.test"
      )
    RUBY

    expect(autocorrect(source)).to eq(<<~RUBY)
      have_attributes(
        client_id: "client-id",
        client_secret: "client-secret",
        host: "app.example.test"
      )
    RUBY
  end

  it "allows single-line calls and hashes" do
    expect(investigate("call(1, 2, a: 3)\nsettings = { a: 1, b: 2 }\n")).to be_empty
  end

  it "allows elements that begin on the opening bracket's line" do
    expect(investigate("call(1, -> {\n  2\n})\nsettings = { a: 1, b: {\n  c: 2\n} }\n")).to be_empty
  end

  it "leaves elements spread over several lines to the stock line-break cops" do
    expect(investigate("call(\n  1, 2,\n  3\n)\n")).to be_empty
  end

  it "allows elements that each start a line" do
    expect(investigate("call(\n  1,\n  a: 2\n)\nsettings = {\n  a: 1,\n  b: 2\n}\n")).to be_empty
  end

  it "allows elements that share a line with a heredoc opener" do
    expect(investigate("call(\n  <<~A, 1\n    text\n  A\n)\n")).to be_empty
  end

  def processed(source)
    RuboCop::ProcessedSource.new(source, RuboCop::TargetRuby::DEFAULT_VERSION)
  end

  def investigate(source)
    RuboCop::Cop::Team.new([ cop ], config, raise_error: true)
      .investigate(processed(source))
      .offenses
      .map { |offense| [ offense.line, offense.message ] }
  end

  def autocorrect(source)
    correcting_cop = described_class.new(config, autocorrect: true)
    RuboCop::Cop::Commissioner.new([ correcting_cop ], [], raise_error: true)
      .investigate(processed(source))
      .correctors
      .first
      .process
  end
end

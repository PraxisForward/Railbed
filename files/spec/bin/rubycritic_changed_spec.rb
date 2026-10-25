# frozen_string_literal: true

require "rails_helper"
require "open3"
require "tempfile"
require "tmpdir"

RSpec.describe "bin/rubycritic-changed" do
  def check_report(report)
    Tempfile.create([ "rubycritic-report", ".json" ]) do |file|
      file.write(JSON.generate(report))
      file.flush
      stdout, _stderr, status = Open3.capture3(
        Rails.root.join("bin/rubycritic-changed").to_s,
        "--check-report",
        file.path
      )
      return [ status.success?, stdout ]
    end
  end

  def report_for(type:, message:, line: 20)
    {
      "analysed_modules" => [
        {
          "smells" => [
            {
              "type" => type,
              "context" => "Example#work",
              "message" => message,
              "locations" => [ { "path" => "app/services/example.rb", "line" => line } ]
            }
          ]
        }
      ]
    }
  end

  def check_null_base
    Dir.mktmpdir("rubycritic-null-base") do |repo|
      _init_stdout, init_stderr, init_status = Open3.capture3("git", "init", "--quiet", chdir: repo)
      stdout, stderr, status = Open3.capture3(
        Rails.root.join("bin/rubycritic-changed").to_s,
        "0" * 40,
        chdir: repo
      )
      return [ init_status.success?, init_stderr, status.success?, stdout, stderr ]
    end
  end

  it "fails with an actionable location for a high-complexity finding" do
    result = check_report(report_for(type: "HighComplexity", message: "has a flog score of 30", line: 12))

    expect(result).to eq(
      [ false, "app/services/example.rb:12 Example#work HighComplexity: has a flog score of 30\n" ]
    )
  end

  it "fails on a genuinely large method" do
    result = check_report(report_for(type: "TooManyStatements", message: "has approx 15 statements"))

    expect(result).to eq(
      [ false, "app/services/example.rb:20 Example#work TooManyStatements: has approx 15 statements\n" ]
    )
  end

  it "allows a short advisory statement finding" do
    result = check_report(report_for(type: "TooManyStatements", message: "has approx 8 statements"))

    expect(result).to eq([ true, "" ])
  end

  it "allows non-blocking smells" do
    result = check_report(report_for(type: "IrresponsibleModule", message: "has no descriptive comment"))

    expect(result).to eq([ true, "" ])
  end

  it "treats a null push base as Git's empty tree" do
    expect(check_null_base).to eq(
      [ true, "", true, "No changed Ruby files under app/ or lib/.\n", "" ]
    )
  end
end

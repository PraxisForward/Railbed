# frozen_string_literal: true

require "rails_helper"
require "fileutils"
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
      _init_stdout, init_stderr, init_status = Open3.capture3("git", "init", "--quiet", "--template=", chdir: repo)
      stdout, stderr, status = Open3.capture3(
        Rails.root.join("bin/rubycritic-changed").to_s,
        "0" * 40,
        chdir: repo
      )
      return [ init_status.success?, init_stderr, status.success?, stdout, stderr ]
    end
  end

  # The rating rules themselves are covered by the template contract suite through
  # --check-ratings. The examples below spend their time where only a real RubyCritic run
  # can help: rating the base revision from a checkout of that revision.
  def git(repo, *args)
    stdout, stderr, status = Open3.capture3(
      "git",
      "-c",
      "user.name=t",
      "-c",
      "user.email=t@example.com",
      *args,
      chdir: repo
    )
    raise "git #{args.join(' ')} failed: #{stderr}" unless status.success?

    stdout.strip
  end

  def empty_tree(repo)
    stdout, stderr, status = Open3.capture3(
      "git",
      "hash-object",
      "-t",
      "tree",
      "--stdin",
      stdin_data: "",
      chdir: repo
    )
    raise "could not name the empty tree: #{stderr}" unless status.success?

    stdout.strip
  end

  def widget_source(statements)
    body = Array.new(statements) { |index| "    value = [ value, #{index} ].max if value.odd? && #{index}.even?" }
    "class Widget\n  def work(value)\n#{body.join("\n")}\n    value\n  end\nend\n"
  end

  # Yields a committed application together with its base revision, so each example can
  # change the working tree the way a pull request would.
  def committed_app
    Dir.mktmpdir("rubycritic-real") do |repo|
      FileUtils.mkdir_p(File.join(repo, "app"))
      git(repo, "init", "--quiet", "--template=")
      File.write(File.join(repo, "app/widget.rb"), widget_source(2))
      git(repo, "add", ".")
      git(repo, "commit", "--quiet", "-m", "base")
      yield repo, git(repo, "rev-parse", "HEAD")
    end
  end

  # Grows the committed file the way a pull request would, so the base revision has something
  # older to compare the working tree against.
  def grow_widget(repo)
    File.write(File.join(repo, "app/widget.rb"), widget_source(80))
    git(repo, "add", ".")
    git(repo, "commit", "--quiet", "-m", "grown")
  end

  def run_gate(repo, base)
    stdout, stderr, status = Open3.capture3(
      Rails.root.join("bin/rubycritic-changed").to_s,
      base,
      chdir: repo
    )
    [ status.success?, stdout, stderr ]
  end

  def skip_note
    "Rating comparison skipped: Git's empty tree has no commit to rate, so only method smells apply.\n"
  end

  it "fails with an actionable location for a high-complexity finding" do
    result = check_report(report_for(type: "HighComplexity", message: "has a flog score of 30", line: 12))

    expect(result).to eq(
      [ false, "app/services/example.rb:12 Example#work HighComplexity: has a flog score of 30\n" ]
    )
  end

  it "fails a method flog rated past the very-high threshold" do
    result = check_report(report_for(type: "VeryHighComplexity", message: "has a flog score of 70", line: 12))

    expect(result).to eq(
      [ false, "app/services/example.rb:12 Example#work VeryHighComplexity: has a flog score of 70\n" ]
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

  it "measures the base rating on the base revision, not on the working tree" do
    result = committed_app do |repo, base|
      File.write(File.join(repo, "app/widget.rb"), widget_source(80))
      run_gate(repo, base)
    end

    expect(result).to match([ false, /app\/widget\.rb rating fell from [ABC] to [BCDF]/, anything ])
  end

  it "passes a changed file that keeps the rating it already had" do
    result = committed_app do |repo, base|
      File.write(File.join(repo, "app/widget.rb"), "# Touched, unchanged.\n#{widget_source(2)}")
      run_gate(repo, base)
    end

    expect(result).to eq([ true, "RubyCritic changed-code gate passed for 1 file(s).\n", "" ])
  end

  it "requires an added file to be rated B or better" do
    result = committed_app do |repo, base|
      File.write(File.join(repo, "app/slop.rb"), widget_source(90))
      run_gate(repo, base)
    end

    expect(result).to match([ false, /app\/slop\.rb is new and rated [CDF]/, anything ])
  end

  it "skips the rating comparison for an empty-tree base, where every file would look new" do
    result = committed_app do |repo, _base|
      File.write(File.join(repo, "app/extra.rb"), "class Extra\n  def work = 1\nend\n")
      run_gate(repo, empty_tree(repo))
    end

    expect(result).to eq([ true, "#{skip_note}RubyCritic changed-code gate passed for 2 file(s).\n", "" ])
  end

  it "skips the rating comparison for a null push base" do
    result = committed_app do |repo, _base|
      File.write(File.join(repo, "app/extra.rb"), "class Extra\n  def work = 1\nend\n")
      run_gate(repo, "0" * 40)
    end

    expect(result).to eq([ true, "#{skip_note}RubyCritic changed-code gate passed for 2 file(s).\n", "" ])
  end

  it "refuses a revision range instead of the one commit to rate against" do
    result = committed_app do |repo, _base|
      grow_widget(repo)
      run_gate(repo, "HEAD~1..HEAD")
    end

    expect(result).to match([ false, "", /does not name a single commit/ ])
  end
end

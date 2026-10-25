# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "pathname"
require "tempfile"
require "tmpdir"
require "yaml"

class TemplateTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").expand_path

  def test_template_is_valid_ruby
    stdout, status = Open3.capture2e("ruby", "-c", ROOT.join("template.rb").to_s)
    assert status.success?, stdout
  end

  def test_all_cop_requires_resolve
    config = YAML.safe_load_file(ROOT.join("files/.rubocop.yml"), aliases: true)

    config.fetch("require").each do |required_path|
      relative_path = required_path.delete_prefix("./") + ".rb"
      assert ROOT.join("files", relative_path).file?, "Missing #{relative_path}"
    end
  end

  def test_rubocop_presentation_scope_keeps_bareword_readers_enabled
    config = YAML.safe_load_file(ROOT.join("files/.rubocop.yml"), aliases: true)
    cop_config = config.fetch("Quality/PreferBarewordReaders")

    assert_equal true, cop_config.fetch("Enabled")
    assert_equal %w[app/controllers/**/* app/mailers/**/* app/views/**/*], cop_config.fetch("Exclude")
  end

  def test_template_delivers_rubocop_presentation_scope_spec
    path = "spec/config/rubocop_scope_spec.rb"

    assert_includes ROOT.join("template.rb").read, %(copy_template_file "#{path}")
    assert ROOT.join("files", path).file?, "Missing template asset: #{path}"
  end

  def test_template_assets_exist
    template = ROOT.join("template.rb").read
    copied_paths = template.scan(/copy_template_file \"([^\"]+)\"/).flatten

    copied_paths.each do |path|
      assert ROOT.join("files", path).file?, "Missing template asset: #{path}"
    end
  end

  def test_rubocop_caps_lines_and_puts_one_element_per_line
    config = YAML.safe_load_file(ROOT.join("files/.rubocop.yml"), aliases: true)

    assert_equal 120, config.fetch("Layout/LineLength").fetch("Max")
    assert_equal "with_fixed_indentation", config.fetch("Layout/ArgumentAlignment").fetch("EnforcedStyle")
    %w[
      Layout/MultilineHashKeyLineBreaks
      Layout/MultilineMethodArgumentLineBreaks
      Quality/OneElementPerLine
    ].each do |cop|
      assert_equal true, config.fetch(cop).fetch("Enabled"), "#{cop} must be enabled"
    end
    assert_equal %w[array hash heredoc method_call], config.fetch("RSpec/ExampleLength").fetch("CountAsOne")
  end

  def test_template_delivers_one_element_per_line_cop
    template = ROOT.join("template.rb").read

    %w[
      lib/rubocop/cop/quality/one_element_per_line.rb
      spec/rubocop/cop/quality/one_element_per_line_spec.rb
    ].each do |path|
      assert_includes template, %(copy_template_file "#{path}")
      assert ROOT.join("files", path).file?, "Missing template asset: #{path}"
    end
  end

  def test_warespace_namespace_does_not_leak_into_generated_files
    generated_files = ROOT.join("files").glob("**/*").select(&:file?)
    leaks = generated_files.select { |path| path.read.include?("WareSpace") }

    assert_empty leaks, "WareSpace references remain in: #{leaks.join(', ')}"
  end

  def test_template_keeps_the_default_rails_schema_format
    template = ROOT.join("template.rb").read

    refute_includes template, "schema_format"
  end

  def test_every_gem_has_a_bounded_version
    gemfile = ROOT.join("files/Gemfile.tt").read
    unbounded = gemfile.lines.grep(/^\s*gem /).reject { |line| line.match?(/gem \"[^\"]+\", \"(?:~>|<|<=|=)/) }

    assert_empty unbounded, "Unbounded gems:\n#{unbounded.join}"
  end

  def test_repo_scoped_skills_have_required_frontmatter
    skill_files = ROOT.join("files/.agents/skills").glob("*/SKILL.md")

    assert_equal 4, skill_files.size

    skill_files.each do |path|
      contents = path.read
      assert_match(/\A---\n/, contents, "Missing frontmatter: #{path}")
      assert_match(/^name: [a-z0-9-]+$/, contents, "Missing skill name: #{path}")
      assert_match(/^description: .+$/, contents, "Missing skill description: #{path}")
    end
  end

  def test_template_links_repo_skills_for_claude_code
    template = ROOT.join("template.rb").read

    assert_includes template, 'empty_directory ".claude/skills"'
    assert_includes template, 'create_link ".claude/skills/#{skill}", "../../.agents/skills/#{skill}"'
  end

  def test_lockfile_tracks_only_upstream_managed_skills
    lockfile = JSON.parse(ROOT.join("files/skills-lock.json").read)

    assert_equal 1, lockfile.fetch("version")
    assert_equal %w[conventional-comments conventional-commits tdd-workflow], lockfile.fetch("skills").keys.sort
    refute_includes lockfile.fetch("skills"), "team-code-review"
  end

  def test_team_code_review_is_tailored_to_generated_rails_stack
    review_skill = ROOT.join("files/.agents/skills/team-code-review/SKILL.md").read

    [
      "bin/ci",
      "RSpec",
      "Sorbet",
      "Tapioca",
      "ViewComponent",
      "schema.rb",
      "composition over inheritance",
      "POODR"
    ].each do |term|
      assert_includes review_skill, term
    end
  end

  def test_changed_code_gate_blocks_high_complexity_with_an_actionable_location
    success, output = check_rubycritic_report(
      report_for(type: "HighComplexity", message: "has a flog score of 30", line: 12)
    )

    refute success
    assert_equal "app/services/example.rb:12 Example#work HighComplexity: has a flog score of 30\n", output
  end

  def test_changed_code_gate_blocks_genuinely_large_methods
    success, output = check_rubycritic_report(
      report_for(type: "TooManyStatements", message: "has approx 15 statements")
    )

    refute success
    assert_equal "app/services/example.rb:20 Example#work TooManyStatements: has approx 15 statements\n", output
  end

  def test_changed_code_gate_allows_short_advisory_statement_findings
    success, output = check_rubycritic_report(
      report_for(type: "TooManyStatements", message: "has approx 8 statements")
    )

    assert success
    assert_empty output
  end

  def test_changed_code_gate_allows_non_blocking_smells
    success, output = check_rubycritic_report(
      report_for(type: "IrresponsibleModule", message: "has no descriptive comment")
    )

    assert success
    assert_empty output
  end

  def test_changed_code_gate_treats_a_null_base_as_the_empty_tree
    Dir.mktmpdir("rubycritic-null-base") do |repo|
      _stdout, stderr, status = Open3.capture3("git", "init", "--quiet", chdir: repo)
      assert status.success?, stderr

      stdout, stderr, status = Open3.capture3(
        ROOT.join("files/bin/rubycritic-changed").to_s, "0" * 40, chdir: repo
      )
      assert status.success?, stderr
      assert_equal "No changed Ruby files under app/ or lib/.\n", stdout
    end
  end

  def test_template_delivers_changed_code_quality_assets
    template = ROOT.join("template.rb").read

    %w[AGENTS.md bin/rubycritic-changed docs/guides/testing.md spec/bin/rubycritic_changed_spec.rb].each do |path|
      assert_includes template, %(copy_template_file "#{path}")
      assert ROOT.join("files", path).file?, "Missing template asset: #{path}"
    end
  end

  def test_rspec_install_is_non_interactive
    assert_includes ROOT.join("template.rb").read, 'run "bin/rails generate rspec:install --force"'
  end

  def test_template_delivers_bundler_connection_pool_sorbet_shim
    template = ROOT.join("template.rb").read

    assert_includes template, 'copy_template_file "sorbet/rbi/shims/bundler_connection_pool.rbi"'
    assert ROOT.join("files/sorbet/rbi/shims/bundler_connection_pool.rbi").file?
  end

  def test_generated_ci_fetches_history_and_runs_changed_code_gate
    workflow = ROOT.join("files/.github/workflows/ci.yml").read

    assert_includes workflow, "fetch-depth: 0"
    assert_includes workflow, "RUBYCRITIC_BASE: ${{ github.event.pull_request.base.sha || github.event.before }}"
    assert_includes workflow, 'bin/rubycritic-changed "$RUBYCRITIC_BASE"'
  end

  def test_generated_local_ci_runs_both_rubycritic_checks
    ci_config = ROOT.join("files/config/ci.rb").read

    assert_includes ci_config, 'step "Quality: RubyCritic", "bin/rubycritic"'
    assert_includes ci_config, 'step "Quality: Changed RubyCritic"'
    assert_includes ci_config, "bin/rubycritic-changed"
  end

  def test_integration_lane_runs_generated_quality_and_security_checks
    test_runner = ROOT.join("bin/test").read

    %w[bin/rubycritic bin/rubycritic-changed bin/brakeman bin/bundler-audit].each do |command|
      assert_includes test_runner, command
    end
    assert_includes test_runner, "bin/importmap audit"
  end

  def test_solid_tables_move_to_the_primary_database_before_it_is_prepared
    template = ROOT.join("template.rb").read
    after_bundle = template[/^after_bundle do\n.*\z/m]

    assert_operator after_bundle.index("move_solid_tables_to_primary_database"), :<,
      after_bundle.index('run "bin/rails db:prepare"')
    %w[config/database.yml config/cable.yml config/cache.yml config/environments/production.rb].each do |path|
      assert_includes template, %(gsub_file! "#{path}")
    end
    assert_includes template, 'remove_file schema_path'
    assert_includes template, 'run "bundle exec rubocop -A Gemfile db/migrate"'
  end

  def test_development_works_jobs_like_production_and_tests_keep_the_test_adapter
    template = ROOT.join("template.rb").read

    assert_includes template, "config.active_job.queue_adapter = :solid_queue"
    assert_includes template, "config.active_job.queue_adapter = :test"
    assert_includes template, 'append_to_file "Procfile.dev", "jobs: bin/jobs\\n"'
  end

  def test_boolean_cop_skips_the_copied_solid_queue_migration
    config = YAML.safe_load_file(ROOT.join("files/.rubocop.yml"), aliases: true)

    assert_equal %w[db/migrate/*_create_solid_queue_tables.rb], config.fetch("Quality/TimeForABoolean").fetch("Exclude")
  end

  private

  def check_rubycritic_report(report)
    Tempfile.create(["rubycritic-report", ".json"]) do |file|
      file.write(JSON.generate(report))
      file.flush
      stdout, _stderr, status = Open3.capture3(
        ROOT.join("files/bin/rubycritic-changed").to_s, "--check-report", file.path
      )
      return [status.success?, stdout]
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
              "locations" => [{"path" => "app/services/example.rb", "line" => line}]
            }
          ]
        }
      ]
    }
  end
end

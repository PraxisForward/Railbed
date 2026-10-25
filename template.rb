# frozen_string_literal: true

require "fileutils"

SOURCE_ROOT = File.expand_path("files", __dir__)
ASSET_BASE_URL = ENV.fetch(
  "RAILS_TEMPLATE_ASSET_BASE_URL",
  "https://raw.githubusercontent.com/Praxis-Works/Railbed/main/files"
)
source_paths.unshift(SOURCE_ROOT) if Dir.exist?(SOURCE_ROOT)

AGENT_SKILLS = %w[
  conventional-comments
  conventional-commits
  tdd-workflow
  team-code-review
].freeze

def copy_template_file(path, destination = path)
  if Dir.exist?(SOURCE_ROOT)
    copy_file path, destination, force: true
  else
    get "#{ASSET_BASE_URL}/#{path}", destination
  end
end

say "Applying Damian's Rails defaults", :green

copy_template_file "Gemfile.tt", "Gemfile"

remove_dir "test"

copy_template_file ".rspec"
copy_template_file ".reek.yml"
copy_template_file ".rubocop.yml"
copy_template_file ".rubycritic.yml"
copy_template_file ".agents/skills/conventional-comments/SKILL.md"
copy_template_file ".agents/skills/conventional-commits/SKILL.md"
copy_template_file ".agents/skills/conventional-commits/references/commit-examples.md"
copy_template_file ".agents/skills/tdd-workflow/SKILL.md"
copy_template_file ".agents/skills/team-code-review/SKILL.md"
copy_template_file ".github/workflows/ci.yml"
copy_template_file "AGENTS.md"
copy_template_file "bin/dependency-policy"
copy_template_file "bin/rubycritic"
copy_template_file "bin/rubycritic-changed"
copy_template_file "bin/tapioca"
copy_template_file "config/bundler-audit.yml"
copy_template_file "config/ci.rb"
copy_template_file "config/initializers/strong_migrations.rb"
copy_template_file "docs/guides/testing.md"
copy_template_file "lib/rubocop/cop/quality/no_inline_class.rb"
copy_template_file "lib/rubocop/cop/quality/one_element_per_line.rb"
copy_template_file "lib/rubocop/cop/quality/prefer_bareword_readers.rb"
copy_template_file "lib/rubocop/cop/quality/time_for_a_boolean.rb"
copy_template_file "sorbet/config"
copy_template_file "sorbet/tapioca/config.yml"
copy_template_file "sorbet/tapioca/require.rb"
copy_template_file "sorbet/rbi/shims/ci.rbi"
copy_template_file "sorbet/rbi/shims/bundler_connection_pool.rbi"
copy_template_file "spec/config/sorbet_strictness_spec.rb"
copy_template_file "spec/config/testing_stack_spec.rb"
copy_template_file "spec/config/rubocop_scope_spec.rb"
copy_template_file "spec/bin/rubycritic_changed_spec.rb"
copy_template_file "spec/rubocop/cop/quality/no_inline_class_spec.rb"
copy_template_file "spec/rubocop/cop/quality/one_element_per_line_spec.rb"
copy_template_file "spec/rubocop/cop/quality/prefer_bareword_readers_spec.rb"
copy_template_file "spec/rubocop/cop/quality/time_for_a_boolean_spec.rb"
copy_template_file "spec/spec_helper.rb"
copy_template_file "spec/rails_helper.rb"
copy_template_file "skills-lock.json"

empty_directory ".claude/skills"
AGENT_SKILLS.each do |skill|
  create_link ".claude/skills/#{skill}", "../../.agents/skills/#{skill}"
end

create_file ".gitignore" unless File.exist?(".gitignore")
append_to_file ".gitignore", "\n/vendor/bundle\n/coverage\n"

gsub_file "config/application.rb", "config.autoload_lib(ignore: %w[assets tasks])",
  "config.autoload_lib(ignore: %w[assets rubocop tasks])"

application <<~RUBY
  config.generators do |generators|
    generators.test_framework :rspec
    generators.fixture_replacement :factory_bot, dir: "spec/factories"
  end
RUBY

environment <<~RUBY, env: :development
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true
  end
RUBY

environment <<~RUBY, env: :test
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.raise = true
  end
RUBY

inject_into_class "app/jobs/application_job.rb", "ApplicationJob", <<~RUBY
  include Bullet::ActiveJob if defined?(Bullet) && Rails.env.development?

RUBY

after_bundle do
  run "bin/rails generate rspec:install --force"
  copy_template_file ".rspec"
  copy_template_file "spec/spec_helper.rb"
  copy_template_file "spec/rails_helper.rb"

  ruby_files = Dir.glob("{app,lib}/**/*.rb")
  ruby_files.each do |path|
    contents = File.read(path)
    next if contents.start_with?("# typed:")

    typed_contents = if contents.start_with?("# frozen_string_literal: true\n")
      contents.sub("# frozen_string_literal: true\n", "# typed: strict\n# frozen_string_literal: true\n")
    else
      "# typed: strict\n\n" + contents
    end

    File.write(path, typed_contents)
  end

  run "bin/tapioca gems"
  run "bin/rails db:prepare"
  run "bin/tapioca dsl"
  run "bundle exec rubocop -A Gemfile"

  chmod "bin/dependency-policy", 0o755
  chmod "bin/rubycritic", 0o755
  chmod "bin/rubycritic-changed", 0o755
  chmod "bin/tapioca", 0o755

  say "Rails quality stack installed. Run bin/ci to verify the application.", :green
end

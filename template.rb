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

SOLID_SCHEMAS = {
  "cache" => "create_solid_cache_tables",
  "queue" => "create_solid_queue_tables",
  "cable" => "create_solid_cable_tables"
}.freeze
PRODUCTION_DATABASES =
  /^production:\n  primary: &primary_production\n((?:    .*\n)+)(?:  (?:cache|queue|cable):\n(?:    .*\n)+)+/

# Rails gives Solid Queue, Cache, and Cable their own production databases. Railbed
# keeps their tables in the primary database instead, so a job enqueue commits or
# rolls back with the data it depends on. Each installer's schema file becomes an
# ordinary migration, so it matches the installed gem version. gsub_file! fails
# generation if a Rails or gem upgrade changes the files these edits expect.
def move_solid_tables_to_primary_database
  version = "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
  timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i

  SOLID_SCHEMAS.each_with_index do |(name, migration_name), index|
    schema_path = "db/#{name}_schema.rb"
    create_file "db/migrate/#{timestamp + index}_#{migration_name}.rb",
      solid_migration(File.read(schema_path), schema_path, migration_name.camelize, version)
    remove_file schema_path
  end

  gsub_file! "config/database.yml", PRODUCTION_DATABASES do |production|
    primary = production[PRODUCTION_DATABASES, 1].gsub(/^  /, "")
    "# One database holds the application tables and the Solid Queue, Solid Cache,\n" \
      "# and Solid Cable tables, so a job enqueue can commit in the same transaction\n" \
      "# as the data it depends on.\nproduction:\n#{primary}"
  end
  gsub_file! "config/cable.yml", /^  connects_to:\n    database:\n      writing: cable\n/, ""
  gsub_file! "config/cache.yml", /^  database: cache\n/, ""
  gsub_file! "config/environments/production.rb", /^  config\.solid_queue\.connects_to = .*\n/, ""
  append_to_file "Procfile.dev", "jobs: bin/jobs\n"
end

def solid_migration(schema, schema_path, migration_class, version)
  body = schema[/\.define\(version: [\d_]+\) do\n(.*)^end/m, 1].gsub(", force: :cascade", "")
  foreign_keys = body.scan(/^  add_foreign_key .*\n/).join
  body = body.gsub(/^  add_foreign_key .*\n/, "").rstrip + "\n"
  unless foreign_keys.empty?
    body += "\n  # The referenced tables are created above in this migration and are still\n" \
      "  # empty, so validating these keys cannot block writes.\n" \
      "  safety_assured do\n#{foreign_keys.gsub(/^/, '  ')}  end\n"
  end

  "# Copied from #{schema_path} so these tables live in the primary database.\n" \
    "class #{migration_class} < ActiveRecord::Migration[#{version}]\n" \
    "  def change\n#{body.gsub(/^(?=.)/, '  ')}  end\nend\n"
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
copy_template_file "docs/guides/configuration.md"
copy_template_file "docs/guides/testing.md"
copy_template_file "lib/credentials.rb"
copy_template_file "lib/rubocop/cop/quality/no_direct_env.rb"
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
copy_template_file "spec/lib/credentials_spec.rb"
copy_template_file "spec/rubocop/cop/quality/no_direct_env_spec.rb"
copy_template_file "spec/rubocop/cop/quality/no_inline_class_spec.rb"
copy_template_file "spec/rubocop/cop/quality/one_element_per_line_spec.rb"
copy_template_file "spec/rubocop/cop/quality/prefer_bareword_readers_spec.rb"
copy_template_file "spec/rubocop/cop/quality/time_for_a_boolean_spec.rb"
copy_template_file "spec/spec_helper.rb"
copy_template_file "spec/rails_helper.rb"
copy_template_file "spec/support/credentials_helpers.rb"
copy_template_file "spec/support/env_helpers.rb"
copy_template_file "skills-lock.json"

empty_directory ".claude/skills"
AGENT_SKILLS.each do |skill|
  create_link ".claude/skills/#{skill}", "../../.agents/skills/#{skill}"
end

create_file ".gitignore" unless File.exist?(".gitignore")
append_to_file ".gitignore", "\n/vendor/bundle\n/coverage\n/config/credentials/*.key\n"

# Loaded once rather than reloaded, so initializers can call Credentials.dig at boot.
gsub_file "config/application.rb", "config.autoload_lib(ignore: %w[assets tasks])",
  "config.autoload_lib_once(ignore: %w[assets rubocop tasks])"

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

environment <<~RUBY, env: :development
  # Match production: jobs enqueue into the primary database. bin/dev runs bin/jobs to work them.
  config.active_job.queue_adapter = :solid_queue
RUBY

environment <<~RUBY, env: :test
  config.active_job.queue_adapter = :test
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

  move_solid_tables_to_primary_database

  run "bin/tapioca gems"
  run "bin/rails db:prepare"
  run "bin/tapioca dsl"
  run "bundle exec rubocop -A Gemfile db/migrate"

  chmod "bin/dependency-policy", 0o755
  chmod "bin/rubycritic", 0o755
  chmod "bin/rubycritic-changed", 0o755
  chmod "bin/tapioca", 0o755

  say "Rails quality stack installed. Run bin/ci to verify the application.", :green
end

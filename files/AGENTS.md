# Rails Application Contributor Guide

## Configuration

Read settings and secrets with `Credentials.dig(:service, :key)`. A non-blank `SERVICE_KEY` environment variable overrides the current environment's Rails credentials. Do not read `ENV` in `app/`, `lib/`, or `config/initializers/`. `Quality/NoDirectEnv` enforces this rule, and `lib/credentials.rb` is the only exception. Never commit `config/master.key` or `config/credentials/*.key`. See `docs/guides/configuration.md`.

## Quality Commands

```bash
bin/dependency-policy
bundle exec rspec
bin/rubocop
bundle exec srb tc
bin/rubycritic
bin/rubycritic-changed <base-ref>
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
env RAILS_ENV=test bin/rails db:seed:replant
```

## Definition of Done

A change is complete when:

- Focused specs and the full relevant RSpec suite pass.
- RuboCop, Sorbet, and relevant security checks pass.
- `bin/rubycritic-changed <base-ref>` passes: no Ruby file under `app/` or `lib/` that the change touches has a worse RubyCritic rating letter than it had on `<base-ref>`, every added file is rated B or better, and no changed file has a blocking method smell. Each failure names the file and its rating before and after.
- `bin/rubycritic` still prints the codebase-wide score, which fails only below the 90/100 backstop in `.rubycritic.yml`.
- New behavior has meaningful success, failure, and boundary coverage.

Short explicit mappings may remain visible in RubyCritic's focused report. Do not introduce metaprogramming solely to silence an advisory metric.

## Database

One PostgreSQL database holds the application tables and the Solid Queue, Solid Cache, and Solid Cable tables in every environment. A job enqueued inside a transaction commits or rolls back with the data it depends on. Their tables are ordinary migrations in `db/migrate` and appear in `db/schema.rb`. There are no `queue`, `cache`, or `cable` database entries or `db/*_schema.rb` files. Development runs jobs through Solid Queue, and `bin/dev` starts `bin/jobs` to work them. Tests use the Active Job test adapter. To upgrade a Solid gem that ships new tables, add a migration for them.

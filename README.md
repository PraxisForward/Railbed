# Railbed

**An opinionated, agent-ready foundation for production Rails applications.**

Start your Rails application on solid ground. Railbed turns a new Rails 8.1
application into a production-minded starting point with testing, typing,
security checks, dependency policy, and CI already in place.

It gives developers and coding agents the same explicit conventions and the
same fast feedback loop. It does not generate application features or hide
Rails behind another framework.

An open-source project from Praxis.

## Why Railbed

A fresh Rails application is intentionally flexible. That is useful, but it
also leaves every team to make the same early decisions about tests, types,
code quality, database safety, and CI.

Railbed makes those decisions once and encodes them in the repository. The
result is a codebase with fewer ambiguous choices, enforceable boundaries, and
one command that tells a developer or coding agent whether a change is ready.

## What it installs

### Rails foundation

- PostgreSQL with Rails' default `schema.rb`
- Tailwind CSS, importmap, Turbo, and Stimulus
- Solid Queue, Solid Cache, and Solid Cable on the primary database, so a job
  enqueue commits or rolls back with the data it depends on
- ViewComponent
- `fx` for database functions and views
- Timestamp-backed booleans

### Tests and feedback

- RSpec and FactoryBot
- Shoulda Matchers
- SimpleCov
- WebMock
- Capybara and Selenium
- Bullet N+1 detection, configured to fail in test

### Types and code quality

- Sorbet strict mode
- 120-column lines, with `Quality/OneElementPerLine` and the stock line-break
  cops putting each argument or hash key on its own line once a call or hash
  breaks across lines
- Tapioca gem and DSL RBI generation
- Rails Omakase with RSpec, FactoryBot, and ViewComponent RuboCop plugins
- Custom cops for inline classes, direct instance-variable reads, and boolean
  database columns
- RubyCritic with a 95/100 aggregate minimum score and a changed-code
  complexity gate

### Safety and CI

- Strong Migrations
- Brakeman
- Bundler Audit
- A bounded dependency policy
- A local `bin/ci` entry point
- GitHub Actions using the same CI configuration
- Repo-scoped agent skills for TDD, Conventional Commits, Conventional Comments,
  and Rails-aware team code review, shared with Codex and Claude Code

## Requirements

Railbed currently targets:

- Ruby 4.0.5
- Rails 8.1.3
- PostgreSQL

The examples use [mise](https://mise.jdx.dev/) to select the expected Ruby
version, but mise is not required.

## Create an application

From a local clone of Railbed:

```bash
mise exec ruby@4.0.5 -- rails new my_app \
  --database=postgresql \
  --css=tailwind \
  --template="$(pwd)/template.rb"
```

From GitHub:

```bash
mise exec ruby@4.0.5 -- rails new my_app \
  --database=postgresql \
  --css=tailwind \
  --template=https://raw.githubusercontent.com/Praxis-Works/Railbed/main/template.rb
```

Railbed reads its supporting files from the local clone when available and
fetches them from the repository's raw `main` URL when invoked remotely. Set
`RAILS_TEMPLATE_ASSET_BASE_URL` to test assets from a fork or branch.

## One database

Rails 8 gives Solid Queue, Solid Cache, and Solid Cable separate production
databases. Railbed keeps one database instead. During generation it turns each
installer's `db/*_schema.rb` into an ordinary migration, removes the extra
production entries from `config/database.yml` and the `connects_to` settings
from `config/cable.yml`, `config/cache.yml`, and `config/environments/production.rb`,
and runs the migrations into `db/schema.rb`. Development uses Solid Queue too,
and `bin/dev` starts `bin/jobs`.

To adopt this in an existing Railbed application, copy each `db/*_schema.rb`
body into a migration, delete the schema files, make those edits, and run
`bin/rails db:migrate`. In production, the old queue, cache, and cable databases
are no longer read. Drain the queue before you deploy.

## Verify your generated application

Run the complete quality and safety suite inside the generated application:

```bash
bin/ci
```

For the incremental maintainability check, compare changed application and
library Ruby files with the branch base:

```bash
bin/rubycritic
bin/rubycritic-changed <base-ref>
```

The changed-code gate blocks `HighComplexity` and `TooManyStatements` findings
at 10 or more statements. Generated applications include `AGENTS.md` and
`docs/guides/testing.md` with the complete quality workflow and Definition of
Done.

Generated gem and DSL RBIs are specific to the application and should be
committed.

## Agent skills

Generated applications keep the canonical repo-scoped skills under
`.agents/skills` for Codex and create per-skill symlinks under `.claude/skills`
for Claude Code. The `tdd-workflow`, `conventional-commits`, and
`conventional-comments` skills are tracked in `skills-lock.json` and can be
refreshed from their upstream repositories with:

```bash
DISABLE_TELEMETRY=1 npx skills update --project --yes
```

Review skill updates before committing them. The `team-code-review` skill is
maintained by Railbed rather than the lockfile because it is tailored to the
generated Rails stack, including RSpec, Sorbet/Tapioca, Strong Migrations,
`schema.rb`, ViewComponent, Solid Queue, Bullet, Brakeman, and `bin/ci`.

## Develop Railbed

Run the fast structural checks:

```bash
bin/test
```

Run an end-to-end generation test in a temporary directory:

```bash
INTEGRATION=1 bin/test
```

## Philosophy

Railbed is opinionated by design. Its defaults favor explicitness, fast
feedback, and production safety over maximum flexibility.

Use the pieces that fit your application. Change them when your constraints
demand it. Keep the reasoning visible so the next developer—or coding
agent—does not have to guess.

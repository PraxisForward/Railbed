# Testing and Quality

Run the full local quality stack with `bin/ci`. The individual checks are:

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

## Ruby maintainability

`.rubycritic.yml` keeps an aggregate minimum score of 95/100 across `app/` and `lib/`. This is a broad health check, but an aggregate score can hide a newly introduced complex method.

Run `bin/rubycritic-changed <base-ref>` against the branch or pull-request base as well. It analyzes changed Ruby files under `app/` and `lib/`, and fails on RubyCritic `HighComplexity` findings or `TooManyStatements` findings of 10 or more statements. Its output includes the file, line, context, smell type, and message for each blocking finding.

`bin/ci` runs both checks. Set `RUBYCRITIC_BASE` to the intended comparison revision; when it is unset, the local CI workflow uses Git's empty tree so the initial generated application receives the same strict check.

Shorter statement-count findings and other smells remain advisory and visible in RubyCritic's focused report. Keep short explicit mappings readable; do not introduce metaprogramming solely to satisfy a metric.

CI fetches complete Git history and compares against the pull-request base SHA or the previous push SHA. On a repository's initial push, GitHub's null previous SHA is normalized to Git's empty tree so the first quality run analyzes all application and library Ruby files.

## RuboCop scope

`Quality/PreferBarewordReaders` remains enforced for application and domain Ruby, but excludes controllers, mailers, and views. Instance variables are conventional Rails presentation state in those framework-facing layers. This is deliberate cop scope, not a legacy todo-baseline exclusion.

## Line layout

Lines are at most 120 columns. Once a call's arguments or a hash's keys break after the opening bracket, each element starts its own line:

```ruby
Open3.capture3(
  "bin/rubycritic-changed",
  "--check-report",
  path
)
```

`Layout/MultilineMethodArgumentLineBreaks` and `Layout/MultilineHashKeyLineBreaks` report elements spread over several lines. `Quality/OneElementPerLine` reports the case they skip, where every element shares the one line after the bracket, and autocorrects it. An element that shares a line with a heredoc opener is allowed. Arguments use fixed indentation rather than aligning with the opening bracket.

`RSpec/ExampleLength` counts a multiline array, hash, heredoc, or method call as one line, so this layout does not push an example over the limit.

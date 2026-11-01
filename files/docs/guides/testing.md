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

Two checks cover maintainability, and only one of them gates a change.

`bin/rubycritic-changed <base-ref>` is the gate. Every Ruby file under `app/` and `lib/` that the change touches must not end up with a worse RubyCritic rating letter than it had on `<base-ref>`: a file that falls from A to B fails, and a file that stays at C is fine. A file with no counterpart on the base has no rating to keep, so it must be rated B or better. Git names both paths of a rename, so a rename is judged against the file it came from, while an addition and a copy count as new files. Each failure prints the file and the rating before and after, together with the blocking `HighComplexity` findings and the `TooManyStatements` findings of 10 or more statements, which that run still reports with their line, context, smell type, and message.

The base rating is measured on a checkout of `<base-ref>` itself, in a temporary Git worktree, analysing `app/` and `lib/` in full. RubyCritic matches duplicate code across files, so a rating only means something against the tree it was measured on.

`bin/rubycritic` still prints the codebase-wide score, and `.rubycritic.yml` fails it only below the 90/100 backstop. The rating gate above is what a review acts on; the aggregate score is a backstop against a genuine collapse, such as a RubyCritic upgrade re-scoring the whole application.

`bin/ci` runs both checks. Set `RUBYCRITIC_BASE` to the intended comparison revision. An unset `RUBYCRITIC_BASE` and the null SHA of an initial push both normalize to Git's empty tree, which has no commit to rate: there the rating comparison is skipped, so no existing file is called new, and the method-smell checks still run.

Shorter statement-count findings and other smells remain advisory and visible in RubyCritic's focused report. Keep short explicit mappings readable; do not introduce metaprogramming solely to satisfy a metric.

CI fetches complete Git history and compares against the pull-request base SHA or the previous push SHA. On a repository's initial push, GitHub's null previous SHA is normalized to Git's empty tree so the first quality run still analyzes every application and library Ruby file.

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

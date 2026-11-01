# Rails Template Contributor Guide

This repository builds generated Rails applications from `template.rb` and the assets under `files/`. Changes to generated behavior must update the source asset, the template copy list, and the template tests together.

## Workflow

Use tests to define behavior before implementing it. Run `bin/test` for the fast template contract suite and `INTEGRATION=1 bin/test` when generated application behavior changes.

## Definition of Done

A change is complete when:

- `bin/test` passes, and generation-affecting changes pass `INTEGRATION=1 bin/test`.
- Generated applications keep the aggregate `bin/rubycritic` score above the 90/100 backstop in `files/.rubycritic.yml`, which still prints the score.
- `bin/rubycritic-changed <base-ref>` passes in a generated application: no touched Ruby file under `app/` or `lib/` ends up with a worse RubyCritic rating letter than it had on the base revision, every added file is rated B or better, and no changed file has a blocking method smell.
- Generated RuboCop, Sorbet, dependency-policy, test, and security checks remain passing.
- Contributor guidance, generated documentation, and CI agree with the shipped behavior.

Short explicit mappings may remain visible in RubyCritic's focused report. Do not replace clear code with metaprogramming solely to silence an advisory metric.

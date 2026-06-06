# Contributing to Outbox

Thanks for taking the time to contribute. Outbox is a young library —
PRs, bug reports, and design feedback all welcome.

## Development setup

Prerequisites: Elixir `~> 1.19` and Erlang/OTP `~> 28`. Postgres
required for the test suite.

```bash
git clone https://github.com/Arsenalist/outbox.git
cd outbox
mix deps.get
createdb outbox_test
mix test
```

Format before pushing:

```bash
mix format
```

## Branching & PRs

- `main` is the release branch.
- Branch from `main` for features and fixes; submit a PR.
- Keep PRs scoped — one logical change per PR.
- Update `CHANGELOG.md` under `[Unreleased]` for every user-visible change.
- The architecture test (`test/outbox/architecture_test.exs`) enforces
  the boundary: no `Amplify.*` or other host-app references in `lib/`,
  runtime deps locked to `[:ecto_sql, :oban, :phoenix_pubsub, :jason]`.
  Fix the offending file rather than weakening the test.

## TDD discipline

This codebase was built test-first. Every implementation has a paired
test. When adding behaviour, write the failing test first, watch it go
red, then make it pass. Pull requests adding code without test coverage
will be sent back.

## Versioning

While in `0.x`, the minor version bumps for every breaking change. The
patch version bumps for non-breaking additions and fixes.

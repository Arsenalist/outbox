# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version is in the `0.x` range, any release MAY contain breaking
changes; the minor version is bumped for each one. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the full policy.

## [Unreleased]

## [0.1.0] - 2026-06-06

### Added

- `Outbox.publish/2` — publish a named domain event into the
  `outbox_events` table. Participates in the caller's `Repo.transaction/1`
  (does not open its own).
- `Outbox.Subscriber` behaviour — `events/0` + `handle_event/3` for
  declaring subscribers.
- Built-in Phoenix.PubSub broadcasting — when `pubsub:` is configured,
  the dispatcher broadcasts every dispatched event on the configured
  topic. Consumers pattern-match the events they care about. No
  separate subscriber module to register.
- `Outbox.Testing` — `assert_published/2` and `with_sync_dispatch/1`
  helpers for ExUnit tests.
- `mix outbox.gen.migration` — generator for the `outbox_events` table
  migration. Greenfield-host install path.
- `Outbox.Oban` — library-owned Oban instance with queues
  `[outbox: 10, outbox_prune: 1]` and a cron entry for
  `Outbox.Pruner` (nightly). Host's existing Oban untouched.
- `config :outbox, oban: MyApp.Oban` opt-in escape hatch for hosts that
  want a single Oban instance — validates required queues + cron at
  boot.

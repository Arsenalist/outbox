# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version is in the `0.x` range, any release MAY contain breaking
changes; the minor version is bumped for each one. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the full policy.

## [Unreleased]

### Added

- Ambient context envelope. `Outbox.publish/3` accepts a `:context` option
  and a new `context` jsonb column stores an opaque, host-defined map on
  every event. `Outbox.put_context/1`, `get_context/0`, and `clear_context/0`
  set a per-process ambient context (e.g. in a plug) that is attached to
  every subsequent publish; per-call `:context` overrides ambient keys. The
  context is surfaced to subscribers as `meta.context` and on the PubSub
  broadcast. Atom keys are stringified. **Upgrade:** add the `context`
  column — re-run `mix outbox.gen.migration` for the canonical table, or
  `ALTER TABLE outbox_events ADD COLUMN context jsonb NOT NULL DEFAULT '{}'`.
- Pattern matching in subscriber `events/0`. Entries may be exact names,
  prefix wildcards (`"order.*"`), or `"*"` (all events). A subscriber
  matched by multiple patterns is dispatched once. Exact strings behave as
  before.
- Sampling and transient publishing. `Outbox.publish/3` accepts `:sample`
  (keep with probability `0.0..1.0`, returns `{:ok, :sampled_out}` when
  dropped) and `:transient` (PubSub-only, no row/Oban fan-out, returns
  `{:ok, :transient}`) — for high-volume, loss-tolerant telemetry.
- `Outbox.Idempotency.run_once/3` — exactly-once execution guard for the
  at-least-once delivery contract. Claims `(consumer, event_id)` in a new
  `outbox_consumed_events` table and runs the side-effect only on the first
  delivery; a returned `{:error, _}` or a raise rolls the claim back so a
  retry re-runs. **Upgrade:** create the table via `mix outbox.gen.migration`
  (the canonical migration now includes it).

## [0.1.0-beta.1] - 2026-06-06

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

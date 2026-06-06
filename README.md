# Outbox

Transactional outbox + Oban fan-out + Phoenix.PubSub broadcaster for
Phoenix/Ecto/Oban apps.

Outbox gives you a minimal, opinionated bus: publish a named event from
inside a domain transaction, and Outbox durably persists it, fans it out
to your registered subscribers as Oban jobs, and optionally re-emits it
through `Phoenix.PubSub` for in-process consumers (LiveView, etc.).

> **Status:** early — `0.x`. Public API may shift between minor
> versions. See [CHANGELOG.md](CHANGELOG.md). Production-used by
> [Amplify](https://amplify.events).

## Install

```elixir
def deps do
  [
    {:outbox, "~> 0.1"}
  ]
end
```

Set up the host's Repo and supervision:

```elixir
# config/config.exs
config :outbox, Outbox,
  repo: MyApp.Repo,
  subscribers: [
    MyApp.SearchIndexerSubscriber
  ],
  pubsub: MyApp.PubSub,        # optional — omit to disable PubSub broadcast
  pubsub_topic: "domain_events", # optional, default "domain_events"
  retention_days: 30             # optional, default 30

# lib/my_app/application.ex
children = [
  MyApp.Repo,
  {Phoenix.PubSub, name: MyApp.PubSub},
  Outbox,
  MyAppWeb.Endpoint
]
```

Generate the migration (greenfield hosts only — hosts upgrading from an
existing transactional-outbox table skip this):

```bash
mix outbox.gen.migration
mix ecto.migrate
```

## 60-second tour

### 1. Publish from inside a transaction

```elixir
Repo.transaction(fn ->
  {:ok, product} = Repo.insert(changeset)
  {:ok, _event} = Outbox.publish("product.created", %{"id" => product.id})
  product
end)
```

`publish/2` does NOT open its own transaction — it participates in the
caller's. Roll back the outer transaction and the event row never
persists.

### 2. Subscribe via the behaviour

```elixir
defmodule MyApp.SearchIndexerSubscriber do
  use Outbox.Subscriber

  @impl true
  def events, do: ["product.created", "product.updated"]

  @impl true
  def handle_event("product.created", %{"id" => id}, _meta) do
    MyApp.SearchIndex.reindex(id)
    :ok
  end

  def handle_event("product.updated", %{"id" => id}, _meta) do
    MyApp.SearchIndex.reindex(id)
    :ok
  end
end
```

Each subscriber receives each event **at least once**. Handlers MUST be
idempotent.

### 3. Subscribe via Phoenix.PubSub (LiveView)

When `pubsub:` is configured, the dispatcher broadcasts **every** dispatched
event on the configured topic. LiveView consumers pattern-match the events
they care about and ignore the rest:

```elixir
def mount(_, _, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "domain_events")
  end
  {:ok, socket}
end

def handle_info({:domain_event, "product.created", %{"id" => id}, _meta}, socket) do
  {:noreply, push_event(socket, "product-created", %{id: id})}
end

def handle_info({:domain_event, _, _, _}, socket), do: {:noreply, socket}
```

## Delivery contract

- **At-least-once** per subscriber. Handlers must be idempotent.
- Subscribers fail-isolated: one subscriber raising doesn't block another's job.
- Failed subscriber jobs retry with Oban's standard exponential backoff
  (`max_attempts: 5`).
- Old dispatched events pruned nightly (`retention_days`, default 30).

## Oban instance

Outbox boots its own Oban instance (`Outbox.Oban`) with queues
`[outbox: 10, outbox_prune: 1]` and a cron entry scheduling
`Outbox.Pruner` daily. Your host's existing Oban instance is untouched.
Both instances share the same `oban_jobs` table — Oban filters by queue
name so they never steal each other's work.

To surface Outbox jobs in your ObanWeb dashboard, register the instance:

```elixir
live_dashboard "/dashboard",
  metrics: MyAppWeb.Telemetry,
  additional_pages: [
    oban: ObanWeb.live_dashboard(oban_name: Oban),
    oban_outbox: ObanWeb.live_dashboard(oban_name: Outbox.Oban)
  ]
```

To use your existing Oban instance instead (skip booting `Outbox.Oban`):

```elixir
config :outbox, Outbox, oban: MyApp.Oban
```

Outbox validates at boot that the named instance has the required
queues + cron entry, and raises loudly if they're missing.

## Testing

```elixir
use ExUnit.Case
import Outbox.Testing

test "creating a widget publishes widget.created" do
  MyContext.create_widget(...)
  assert_published("widget.created", %{"id" => "expected_id"})
end

test "subscriber side-effects run end-to-end" do
  with_sync_dispatch(fn ->
    MyContext.create_widget(...)
  end)
  assert MyExternalSystem.was_called?()
end
```

## License

MIT — see [LICENSE](LICENSE).

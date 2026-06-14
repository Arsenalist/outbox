defmodule Outbox.Dispatcher do
  @moduledoc """
  Polls the `outbox_events` table for undispatched events and fans them
  out to subscribers.

  Invoked from `Outbox.Ticker` every ~5s via `Task.Supervisor.start_child/2`.
  Each invocation:

    1. Opens a transaction
    2. Selects up to `@batch_size` undispatched events ordered by `id`
       with `FOR UPDATE SKIP LOCKED` (multi-node safe; concurrent
       invocations on the same node are also safe)
    3. For each event, looks up subscribers via `Outbox.Registry.lookup/1`
       and enqueues one `Outbox.SubscriberJob` per subscriber into the
       `Outbox.Config.oban/0` instance
    4. Marks all processed events `dispatched_at = utc_now()`

  An event with no registered subscribers is still marked dispatched
  (and a debug log is emitted). This prevents re-scanning on every tick.

  Failures don't auto-retry — the next tick (5s later) is the retry.
  This is appropriate for a "drain the outbox" loop with no per-tick
  state to recover.
  """

  import Ecto.Query

  alias Outbox.{OutboxEvent, Registry, SubscriberJob}

  require Logger

  @batch_size 100

  @doc """
  Run one dispatch pass: claim a batch of undispatched events, fan out
  to subscribers, mark dispatched. Returns `:ok`.
  """
  @spec run() :: :ok
  def run do
    repo = Outbox.Config.repo()
    repo.transaction(fn -> dispatch_batch(repo) end)
    :ok
  end

  defp dispatch_batch(repo) do
    events =
      from(e in OutboxEvent,
        where: is_nil(e.dispatched_at),
        order_by: [asc: e.id],
        limit: @batch_size,
        lock: "FOR UPDATE SKIP LOCKED"
      )
      |> repo.all()

    if events == [] do
      :ok
    else
      Logger.info("[Outbox.Dispatcher] processing #{length(events)} events")
      now = DateTime.utc_now()

      Enum.each(events, &fan_out/1)
      Enum.each(events, &pubsub_broadcast/1)

      ids = Enum.map(events, & &1.id)

      from(e in OutboxEvent, where: e.id in ^ids)
      |> repo.update_all(set: [dispatched_at: now])

      :ok
    end
  end

  defp pubsub_broadcast(%OutboxEvent{} = event) do
    case Outbox.Config.pubsub() do
      nil ->
        :ok

      pubsub ->
        topic = Outbox.Config.pubsub_topic()

        Phoenix.PubSub.broadcast(
          pubsub,
          topic,
          {:domain_event, event.name, event.payload,
           %{
             event_id: event.id,
             inserted_at: event.inserted_at,
             context: event.context || %{}
           }}
        )
    end
  end

  defp fan_out(%OutboxEvent{id: id, name: name}) do
    case Registry.lookup(name) do
      [] ->
        Logger.debug("[Outbox.Dispatcher] no subscribers for #{name} (event #{id})")
        :ok

      subscribers ->
        oban = Outbox.Config.oban()

        Enum.each(subscribers, fn subscriber ->
          %{"event_id" => id, "subscriber" => to_string(subscriber)}
          |> SubscriberJob.new()
          |> then(&Oban.insert!(oban, &1))
        end)
    end
  end
end

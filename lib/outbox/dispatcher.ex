defmodule Amplify.DomainEvents.Dispatcher do
  @moduledoc """
  Polls the `outbox_events` table for undispatched events and fans them
  out to subscribers.

  Runs as an Oban cron worker (every 5s by default; see Oban config).
  Each tick:

    1. Opens a transaction
    2. Selects up to `@batch_size` undispatched events ordered by `id`
       with `FOR UPDATE SKIP LOCKED` (multi-node safe)
    3. For each event, looks up subscribers via `Registry.lookup/1`
       and enqueues one `SubscriberJob` per subscriber
    4. Marks all processed events `dispatched_at = utc_now()`

  An event with no registered subscribers is still marked dispatched
  (and a debug log is emitted). This prevents the dispatcher from
  re-scanning the same row on every tick.
  """

  use Oban.Worker, queue: :domain_events_dispatch, max_attempts: 3

  import Ecto.Query

  alias Amplify.DomainEvents.{OutboxEvent, Registry, SubscriberJob}
  alias Amplify.Repo

  require Logger

  @batch_size 100

  @impl Oban.Worker
  def perform(_job) do
    Repo.transaction(fn -> dispatch_batch() end)
    :ok
  end

  defp dispatch_batch do
    events =
      from(e in OutboxEvent,
        where: is_nil(e.dispatched_at),
        order_by: [asc: e.id],
        limit: @batch_size,
        lock: "FOR UPDATE SKIP LOCKED"
      )
      |> Repo.all()

    if events == [] do
      :ok
    else
      Logger.info("[DomainEvents.Dispatcher] processing #{length(events)} events")
      now = DateTime.utc_now()

      Enum.each(events, &fan_out/1)

      ids = Enum.map(events, & &1.id)

      from(e in OutboxEvent, where: e.id in ^ids)
      |> Repo.update_all(set: [dispatched_at: now])

      :ok
    end
  end

  defp fan_out(%OutboxEvent{id: id, name: name}) do
    case Registry.lookup(name) do
      [] ->
        Logger.debug("[DomainEvents.Dispatcher] no subscribers for #{name} (event #{id})")
        :ok

      subscribers ->
        Enum.each(subscribers, fn subscriber ->
          %{"event_id" => id, "subscriber" => to_string(subscriber)}
          |> SubscriberJob.new()
          |> Oban.insert!()
        end)
    end
  end
end

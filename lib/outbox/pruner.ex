defmodule Outbox.Pruner do
  @moduledoc """
  Deletes old, dispatched outbox events.

  Runs as an Oban cron worker on the `Outbox.Oban` instance (nightly by
  default). Retention is configurable via:

      config :outbox, Outbox, retention_days: 30

  Only events with `dispatched_at IS NOT NULL` are eligible for
  deletion. Undispatched events are never pruned regardless of age — if
  an event is sitting undispatched for 30+ days, that signals an
  operational problem the pruner should not mask.
  """

  use Oban.Worker, queue: :outbox_prune, max_attempts: 3

  import Ecto.Query

  alias Outbox.OutboxEvent

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.utc_now() |> DateTime.add(-Outbox.Config.retention_days() * 86_400, :second)
    repo = Outbox.Config.repo()

    {deleted, _} =
      from(e in OutboxEvent,
        where: not is_nil(e.dispatched_at) and e.inserted_at < ^cutoff
      )
      |> repo.delete_all()

    Logger.info(
      "[Outbox.Pruner] deleted #{deleted} dispatched events older than #{Outbox.Config.retention_days()}d"
    )

    :ok
  end
end

defmodule Amplify.DomainEvents.Pruner do
  @moduledoc """
  Deletes old, dispatched outbox events.

  Runs as an Oban cron worker (nightly by default). Retention is
  configurable via:

      config :amplify, Amplify.DomainEvents, retention_days: 30

  Only events with `dispatched_at IS NOT NULL` are eligible for
  deletion. Undispatched events are never pruned regardless of age —
  if an event is sitting undispatched for 30+ days, that signals an
  operational problem the pruner should not mask.
  """

  use Oban.Worker, queue: :domain_events_prune, max_attempts: 3

  import Ecto.Query

  alias Amplify.DomainEvents.OutboxEvent
  alias Amplify.Repo

  require Logger

  @default_retention_days 30

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_days() * 86_400, :second)

    {deleted, _} =
      from(e in OutboxEvent,
        where: not is_nil(e.dispatched_at) and e.inserted_at < ^cutoff
      )
      |> Repo.delete_all()

    Logger.info(
      "[DomainEvents.Pruner] deleted #{deleted} dispatched events older than #{retention_days()}d"
    )

    :ok
  end

  defp retention_days do
    Application.get_env(:amplify, Amplify.DomainEvents, [])
    |> Keyword.get(:retention_days, @default_retention_days)
  end
end

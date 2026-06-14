defmodule Outbox.Idempotency do
  @moduledoc """
  Exactly-once execution guard for at-least-once delivery.

  Subscribers receive each event **at least once**, so a retried job can
  run `handle_event/3` more than once. Wrap the side-effect in
  `run_once/3` to make duplicate deliveries a no-op:

      def handle_event(name, payload, meta) do
        Outbox.Idempotency.run_once(__MODULE__, meta.event_id, fn ->
          Repo.insert(%AuditLog{action: name, ...})
        end)
      end

  The guard claims `(consumer, event_id)` in the `outbox_consumed_events`
  table and runs `fun` only if the claim was newly inserted. The claim and
  `fun` run in one transaction: if `fun` returns `{:error, _}` or raises,
  the claim is rolled back so the next delivery re-runs it. This requires
  the `outbox_consumed_events` table (see `mix outbox.gen.migration`).
  """

  alias Outbox.ConsumedEvent

  @doc """
  Run `fun` at most once per `(consumer, event_id)`.

  Returns:

    * `{:ok, :already_processed}` — this `(consumer, event_id)` was claimed
      by a prior successful run; `fun` is not called.
    * whatever `fun` returns (`:ok`, `{:ok, value}`) — on the first run.
    * `{:error, reason}` — `fun` returned an error; the claim is rolled
      back so a retry re-runs it.

  A raise inside `fun` propagates (after rolling back the claim).
  """
  @spec run_once(String.t() | module(), String.t(), (-> any())) :: any()
  def run_once(consumer, event_id, fun)
      when is_function(fun, 0) and is_binary(event_id) do
    repo = Outbox.Config.repo()
    consumer = to_string(consumer)

    result =
      repo.transaction(fn ->
        if claim(repo, consumer, event_id) do
          case fun.() do
            {:error, reason} -> repo.rollback({:fun_error, reason})
            other -> {:ran, other}
          end
        else
          {:duplicate, :already_processed}
        end
      end)

    case result do
      {:ok, {:duplicate, _}} -> {:ok, :already_processed}
      {:ok, {:ran, value}} -> value
      {:error, {:fun_error, reason}} -> {:error, reason}
    end
  end

  # Inserts the claim row; returns true if WE claimed it, false if a row
  # for (consumer, event_id) already existed. A single ON CONFLICT DO
  # NOTHING statement never aborts the surrounding transaction.
  defp claim(repo, consumer, event_id) do
    entry = %{consumer: consumer, event_id: event_id, inserted_at: DateTime.utc_now()}

    {count, _} =
      repo.insert_all(ConsumedEvent, [entry],
        on_conflict: :nothing,
        conflict_target: [:consumer, :event_id]
      )

    count == 1
  end
end

defmodule Outbox.SubscriberJob do
  @moduledoc """
  Oban worker that runs a single subscriber's `handle_event/3` for one
  outbox event.

  The dispatcher enqueues one job per (event, subscriber) pair so each
  subscriber's failures and retries are isolated.

  Args:
    * `"event_id"` — UUID of the row in `outbox_events`
    * `"subscriber"` — the subscriber module name as a string

  Return-value mapping (Oban semantics):
    * `:ok` → job completes
    * `{:error, reason}` → Oban retries with exponential backoff
    * raised exception → Oban retries with exponential backoff
    * unknown subscriber module → discarded with a clear error
    * outbox event row missing → discarded with a clear error
  """

  use Oban.Worker, queue: :outbox, max_attempts: 5

  alias Outbox.OutboxEvent

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_id" => event_id, "subscriber" => subscriber_str}}) do
    with {:ok, module} <- resolve_subscriber(subscriber_str),
         %OutboxEvent{} = event <- repo().get(OutboxEvent, event_id) do
      module.handle_event(event.name, event.payload, %{
        event_id: event.id,
        inserted_at: event.inserted_at,
        context: event.context || %{}
      })
    else
      nil ->
        {:discard, "outbox event not found: #{event_id}"}

      {:discard, _reason} = result ->
        result
    end
  end

  defp resolve_subscriber(subscriber_str) do
    {:ok, String.to_existing_atom(subscriber_str)}
  rescue
    ArgumentError ->
      {:discard, "subscriber module not loaded: #{subscriber_str}"}
  end

  defp repo, do: Outbox.Config.repo()
end

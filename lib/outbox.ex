defmodule Outbox do
  @moduledoc """
  Public facade for the Outbox transactional event bus.

  Producers call `publish/2` from inside their domain transactions to
  emit events that subscribers (registered in application config) react
  to via `Outbox.SubscriberJob` after the dispatcher fans them out.

  See `Outbox.Subscriber` for the subscriber contract and the README for
  the full architecture overview.
  """

  alias Outbox.OutboxEvent

  @typedoc "Event name. Convention: `<entity>.<past-tense-verb>` (lowercase, dot-separated)."
  @type name :: String.t()

  @typedoc "JSON-serializable payload. Atom keys are converted to strings on insert."
  @type payload :: map()

  @doc """
  Publish a domain event.

  This function performs a single `Repo.insert/1` and **does not open
  its own transaction**. The caller is responsible for wrapping the
  domain write and the `publish/2` call in `Repo.transaction/1` if
  atomicity-with-the-domain-write is required (it almost always is).

  Atom keys in the payload are converted to strings so subscribers
  always see string keys (consistent with what JSONB round-trips
  produce).

  ## Examples

      Repo.transaction(fn ->
        {:ok, product} = Repo.insert(changeset)
        {:ok, _event} = Outbox.publish("product.created", %{"id" => product.id})
        product
      end)
  """
  @spec publish(name(), payload()) :: {:ok, OutboxEvent.t()} | {:error, Ecto.Changeset.t()}
  def publish(name, payload) when is_binary(name) and is_map(payload) do
    repo = Outbox.Config.repo()

    %OutboxEvent{}
    |> OutboxEvent.changeset(%{name: name, payload: stringify_keys(payload)})
    |> repo.insert()
  end

  @doc "Returns a Supervisor child_spec for `Outbox.Application`."
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {Outbox.Application, :start_link, [opts]},
      type: :supervisor
    }
  end

  defp stringify_keys(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      key = if is_atom(k), do: Atom.to_string(k), else: k
      {key, stringify_keys(v)}
    end
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(other), do: other
end

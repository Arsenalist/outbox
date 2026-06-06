defmodule Outbox.OutboxEvent do
  @moduledoc """
  Ecto schema for the `outbox_events` table.

  Each row is one published domain event awaiting dispatch (or already
  dispatched, marked by a non-nil `dispatched_at`).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          payload: map() | nil,
          inserted_at: DateTime.t() | nil,
          dispatched_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "outbox_events" do
    field(:name, :string)
    field(:payload, :map)
    field(:dispatched_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :payload, :dispatched_at])
    |> validate_required([:name, :payload])
    |> validate_change(:name, fn :name, value ->
      cond do
        not is_binary(value) -> [name: "must be a string"]
        String.trim(value) == "" -> [name: "must not be blank"]
        true -> []
      end
    end)
    |> validate_change(:payload, fn :payload, value ->
      if is_map(value), do: [], else: [payload: "must be a map"]
    end)
  end
end

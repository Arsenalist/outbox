defmodule Amplify.DomainEvents.OutboxEvent do
  use Amplify.Schema
  import Ecto.Changeset

  schema "outbox_events" do
    field :name, :string
    field :payload, :map
    field :dispatched_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
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

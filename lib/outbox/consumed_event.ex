defmodule Outbox.ConsumedEvent do
  @moduledoc """
  Ecto schema for the `outbox_consumed_events` table — the idempotency
  ledger written by `Outbox.Idempotency.run_once/3`.

  Each row records that a given `consumer` has processed a given
  `event_id` exactly once. The composite primary key `(consumer,
  event_id)` is what makes a duplicate delivery a no-op.
  """

  use Ecto.Schema

  @type t :: %__MODULE__{
          consumer: String.t() | nil,
          event_id: String.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  @primary_key false
  schema "outbox_consumed_events" do
    field(:consumer, :string, primary_key: true)
    field(:event_id, :string, primary_key: true)
    field(:inserted_at, :utc_datetime_usec)
  end
end

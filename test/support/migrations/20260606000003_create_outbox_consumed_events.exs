defmodule Outbox.TestRepo.Migrations.CreateOutboxConsumedEvents do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:outbox_consumed_events, primary_key: false) do
      add(:consumer, :text, null: false, primary_key: true)
      add(:event_id, :text, null: false, primary_key: true)
      add(:inserted_at, :utc_datetime_usec, null: false, default: fragment("NOW()"))
    end
  end
end

defmodule Outbox.TestRepo.Migrations.CreateOutboxEventsTable do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", "")

    create_if_not_exists table(:outbox_events, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()"))
      add(:name, :text, null: false)
      add(:payload, :jsonb, null: false)
      add(:inserted_at, :utc_datetime_usec, null: false, default: fragment("NOW()"))
      add(:dispatched_at, :utc_datetime_usec)
    end

    create_if_not_exists(
      index(:outbox_events, [:id],
        where: "dispatched_at IS NULL",
        name: :outbox_events_undispatched_idx
      )
    )
  end
end

defmodule Outbox.TestRepo.Migrations.AddContextToOutboxEvents do
  use Ecto.Migration

  def up do
    execute(
      "ALTER TABLE outbox_events ADD COLUMN IF NOT EXISTS context jsonb NOT NULL DEFAULT '{}'"
    )
  end

  def down do
    execute("ALTER TABLE outbox_events DROP COLUMN IF EXISTS context")
  end
end

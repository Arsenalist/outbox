{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)

# Start the test repo
{:ok, _} = Outbox.TestRepo.start_link()

# Run migrations idempotently (create_if_not_exists)
migrations_path = Path.expand("support/migrations", __DIR__)

Ecto.Migrator.run(Outbox.TestRepo, migrations_path, :up, all: true, log: false)

# Switch sandbox to manual mode — each test checks out its own connection
Ecto.Adapters.SQL.Sandbox.mode(Outbox.TestRepo, :manual)

# Start Oban in :manual testing mode against the test repo so jobs are
# enqueued but not auto-executed.
Oban.start_link(
  name: Outbox.Oban,
  repo: Outbox.TestRepo,
  testing: :manual,
  queues: [outbox: 10, outbox_prune: 1]
)

ExUnit.start()

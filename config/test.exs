import Config

config :outbox, ecto_repos: [Outbox.TestRepo]

config :outbox, Outbox,
  repo: Outbox.TestRepo,
  subscribers: [],
  retention_days: 30,
  testing: :manual

config :outbox, Outbox.TestRepo,
  username: System.get_env("OUTBOX_DB_USER", "postgres"),
  password: System.get_env("OUTBOX_DB_PASS", "postgres"),
  hostname: System.get_env("OUTBOX_DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("OUTBOX_DB_PORT", "5436")),
  database: System.get_env("OUTBOX_DB_NAME", "outbox_test"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :logger, level: :warning

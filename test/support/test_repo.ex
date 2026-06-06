defmodule Outbox.TestRepo do
  @moduledoc "Standalone repo for the Outbox library test suite — no host app involved."
  use Ecto.Repo, otp_app: :outbox, adapter: Ecto.Adapters.Postgres
end

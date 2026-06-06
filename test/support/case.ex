defmodule Outbox.DataCase do
  @moduledoc """
  Test case template for DB-touching Outbox tests. Wraps Ecto sandbox setup
  and imports Ecto query helpers.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto.Query
      alias Outbox.TestRepo
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Outbox.TestRepo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end

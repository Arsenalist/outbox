defmodule Outbox.ApplicationTest do
  use ExUnit.Case, async: false

  describe "Outbox.child_spec/1" do
    test "returns a supervisor child_spec" do
      spec = Outbox.child_spec([])
      assert spec.id == Outbox
      assert spec.type == :supervisor
      assert {Outbox.Application, :start_link, [_]} = spec.start
    end
  end

  describe "Outbox.Application.children/1" do
    test "by default starts TaskSupervisor + Outbox.Oban + Ticker" do
      ids =
        Outbox.Application.children(repo: Outbox.TestRepo)
        |> Enum.map(&child_id/1)

      assert Outbox.TaskSupervisor in ids
      assert Outbox.Oban in ids
      assert Outbox.Ticker in ids
    end

    test "when oban: hostObanName is configured, skips starting Outbox.Oban" do
      ids =
        Outbox.Application.children(repo: Outbox.TestRepo, oban: MyHost.Oban)
        |> Enum.map(&child_id/1)

      assert Outbox.TaskSupervisor in ids
      assert Outbox.Ticker in ids
      refute Outbox.Oban in ids
    end
  end

  # Extract the "registered name" of a child — `name:` opt if present,
  # otherwise the module/atom itself.
  defp child_id({mod, opts}) when is_atom(mod) and is_list(opts),
    do: Keyword.get(opts, :name, mod)

  defp child_id(mod) when is_atom(mod), do: mod
  defp child_id(%{id: id}), do: id
end

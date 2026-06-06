defmodule Outbox.PrunerTest do
  use Outbox.DataCase, async: false

  alias Outbox.{OutboxEvent, Pruner}

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(TestRepo, {:shared, self()})
    prev = Application.get_env(:outbox, Outbox)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:outbox, Outbox, prev),
        else: Application.delete_env(:outbox, Outbox)
    end)

    :ok
  end

  defp insert_event!(attrs) do
    {:ok, event} =
      %OutboxEvent{}
      |> OutboxEvent.changeset(Map.merge(%{name: "x.y", payload: %{}}, attrs))
      |> TestRepo.insert()

    # Force inserted_at after insert
    if ts = attrs[:inserted_at] do
      TestRepo.update_all(
        from(e in OutboxEvent, where: e.id == ^event.id),
        set: [inserted_at: ts]
      )
    end

    if dt = attrs[:dispatched_at] do
      TestRepo.update_all(
        from(e in OutboxEvent, where: e.id == ^event.id),
        set: [dispatched_at: dt]
      )
    end

    TestRepo.get!(OutboxEvent, event.id)
  end

  describe "perform/1" do
    test "deletes dispatched rows older than retention" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, retention_days: 30)

      old =
        insert_event!(%{
          inserted_at: DateTime.add(DateTime.utc_now(), -31 * 86_400, :second),
          dispatched_at: DateTime.add(DateTime.utc_now(), -31 * 86_400, :second)
        })

      assert :ok = Pruner.perform(%Oban.Job{args: %{}})
      refute TestRepo.get(OutboxEvent, old.id)
    end

    test "does NOT delete undispatched rows of any age" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, retention_days: 30)

      old_undispatched =
        insert_event!(%{
          inserted_at: DateTime.add(DateTime.utc_now(), -90 * 86_400, :second),
          dispatched_at: nil
        })

      assert :ok = Pruner.perform(%Oban.Job{args: %{}})
      assert TestRepo.get(OutboxEvent, old_undispatched.id)
    end

    test "does NOT delete dispatched rows within retention" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, retention_days: 30)

      recent =
        insert_event!(%{
          inserted_at: DateTime.add(DateTime.utc_now(), -5 * 86_400, :second),
          dispatched_at: DateTime.add(DateTime.utc_now(), -5 * 86_400, :second)
        })

      assert :ok = Pruner.perform(%Oban.Job{args: %{}})
      assert TestRepo.get(OutboxEvent, recent.id)
    end

    test "R-M4: reads Outbox.Config.repo() at call time" do
      # Set repo to a phony module, expect call to fail.
      prev = Application.get_env(:outbox, Outbox)
      Application.put_env(:outbox, Outbox, Keyword.put(prev || [], :repo, NoSuchRepo))

      try do
        assert_raise UndefinedFunctionError, fn ->
          Pruner.perform(%Oban.Job{args: %{}})
        end
      after
        Application.put_env(:outbox, Outbox, prev)
      end

      # Restore — call now succeeds.
      assert :ok = Pruner.perform(%Oban.Job{args: %{}})
    end
  end
end

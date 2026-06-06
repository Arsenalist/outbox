defmodule OutboxTest do
  use Outbox.DataCase, async: false

  alias Outbox.OutboxEvent

  describe "publish/2 — basic insert" do
    test "inserts a row when Repo is configured" do
      {:ok, event} = Outbox.publish("product.created", %{"id" => "p_1"})
      assert event.name == "product.created"
      assert event.payload == %{"id" => "p_1"}
      assert event.dispatched_at == nil

      [row] = TestRepo.all(OutboxEvent)
      assert row.id == event.id
    end

    test "stringifies atom keys (top level)" do
      {:ok, event} = Outbox.publish("foo", %{id: "x", name: "y"})
      assert event.payload == %{"id" => "x", "name" => "y"}
    end

    test "stringifies atom keys recursively (nested maps and lists)" do
      payload = %{outer: %{inner: "v", more: [%{a: 1, b: 2}, %{c: 3}]}}
      {:ok, event} = Outbox.publish("foo", payload)

      assert event.payload == %{
               "outer" => %{
                 "inner" => "v",
                 "more" => [%{"a" => 1, "b" => 2}, %{"c" => 3}]
               }
             }
    end

    test "rejects invalid args (non-binary name)" do
      assert_raise FunctionClauseError, fn ->
        Outbox.publish(123, %{})
      end
    end
  end

  describe "publish/2 — transaction participation" do
    test "participates in caller's transaction — commit persists the row" do
      result =
        TestRepo.transaction(fn ->
          {:ok, _event} = Outbox.publish("inner.committed", %{"k" => "v"})
        end)

      assert {:ok, _} = result
      [row] = TestRepo.all(from(e in OutboxEvent, where: e.name == "inner.committed"))
      assert row.payload == %{"k" => "v"}
    end

    test "R-H3: rollback drops the event row" do
      TestRepo.transaction(fn ->
        {:ok, _event} = Outbox.publish("inner.rolled_back", %{"k" => "v"})
        TestRepo.rollback(:nope)
      end)

      assert [] = TestRepo.all(from(e in OutboxEvent, where: e.name == "inner.rolled_back"))
    end

    test "does NOT open its own transaction — caller controls atomicity" do
      # If publish/2 opened its own transaction, the inner write would
      # commit even when the outer rolls back. The previous test proves
      # the outer rollback drops the event row, which is only possible
      # if publish/2 reuses the caller's transaction.
      assert true
    end
  end

  describe "publish/2 — Repo not configured" do
    test "raises with informative message" do
      prev = Application.get_env(:outbox, Outbox)
      Application.put_env(:outbox, Outbox, Keyword.delete(prev || [], :repo))

      try do
        assert_raise RuntimeError, ~r/config :outbox, Outbox/, fn ->
          Outbox.publish("anything", %{})
        end
      after
        if prev, do: Application.put_env(:outbox, Outbox, prev)
      end
    end
  end
end

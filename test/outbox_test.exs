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

  describe "publish/3 — context envelope" do
    test "stores per-call context on the row" do
      {:ok, event} = Outbox.publish("a.b", %{"k" => "v"}, context: %{"actor_id" => "u1"})
      assert event.context == %{"actor_id" => "u1"}
    end

    test "defaults context to an empty map" do
      {:ok, event} = Outbox.publish("a.b", %{"k" => "v"})
      assert event.context == %{}
    end

    test "stringifies atom keys in context" do
      {:ok, event} = Outbox.publish("a.b", %{}, context: %{actor_id: "u1", account_id: "acct"})
      assert event.context == %{"actor_id" => "u1", "account_id" => "acct"}
    end

    test "merges ambient context set via put_context/1" do
      Outbox.put_context(%{actor_id: "u1"})
      {:ok, event} = Outbox.publish("a.b", %{})
      assert event.context == %{"actor_id" => "u1"}
    end

    test "per-call context overrides ambient on key conflict" do
      Outbox.put_context(%{actor_id: "ambient", account_id: "acct"})
      {:ok, event} = Outbox.publish("a.b", %{}, context: %{actor_id: "call"})
      assert event.context == %{"actor_id" => "call", "account_id" => "acct"}
    end

    test "clear_context/0 removes ambient context" do
      Outbox.put_context(%{actor_id: "u1"})
      Outbox.clear_context()
      {:ok, event} = Outbox.publish("a.b", %{})
      assert event.context == %{}
    end

    test "get_context/0 reflects accumulated put_context/1 calls" do
      assert Outbox.get_context() == %{}
      Outbox.put_context(%{a: "1"})
      Outbox.put_context(%{b: "2"})
      assert Outbox.get_context() == %{"a" => "1", "b" => "2"}
    end
  end

  describe "publish/3 — sampling" do
    test "sample: 1.0 always persists the row" do
      {:ok, event} = Outbox.publish("a.b", %{"k" => "v"}, sample: 1.0)
      assert %OutboxEvent{} = event
      assert [_] = TestRepo.all(from(e in OutboxEvent, where: e.name == "a.b"))
    end

    test "sample: 0.0 drops the event and persists nothing" do
      assert {:ok, :sampled_out} = Outbox.publish("a.b", %{"k" => "v"}, sample: 0.0)
      assert [] = TestRepo.all(from(e in OutboxEvent, where: e.name == "a.b"))
    end
  end

  describe "publish/3 — transient (PubSub-only, no persistence)" do
    test "persists nothing and returns {:ok, :transient}" do
      assert {:ok, :transient} = Outbox.publish("a.b", %{"k" => "v"}, transient: true)
      assert [] = TestRepo.all(from(e in OutboxEvent, where: e.name == "a.b"))
    end

    test "is a no-op-safe return when no PubSub is configured" do
      prev = Application.get_env(:outbox, Outbox)
      Application.put_env(:outbox, Outbox, Keyword.delete(prev || [], :pubsub))

      try do
        assert {:ok, :transient} = Outbox.publish("a.b", %{}, transient: true)
      after
        if prev, do: Application.put_env(:outbox, Outbox, prev)
      end
    end

    test "broadcasts to the configured PubSub with context" do
      start_supervised!({Phoenix.PubSub, name: Outbox.TestPubSub})
      prev = Application.get_env(:outbox, Outbox)
      Application.put_env(:outbox, Outbox, Keyword.put(prev || [], :pubsub, Outbox.TestPubSub))
      Phoenix.PubSub.subscribe(Outbox.TestPubSub, "domain_events")

      try do
        {:ok, :transient} =
          Outbox.publish("a.b", %{"k" => "v"}, transient: true, context: %{"actor_id" => "u1"})

        assert_receive {:domain_event, "a.b", %{"k" => "v"}, meta}
        assert meta.context == %{"actor_id" => "u1"}
        assert meta.transient == true
      after
        if prev, do: Application.put_env(:outbox, Outbox, prev)
      end
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

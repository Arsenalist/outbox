defmodule Outbox.TestingTest do
  use Outbox.DataCase, async: false

  alias Outbox.Testing
  alias Outbox.TestSubscribers.EchoSubscriber

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

  describe "assert_published/2" do
    test "succeeds when event was published" do
      {:ok, _} = Outbox.publish("widget.created", %{"id" => "w_1"})
      assert :ok = Testing.assert_published("widget.created", %{"id" => "w_1"})
    end

    test "succeeds with no payload match" do
      {:ok, _} = Outbox.publish("widget.created", %{"id" => "w_1"})
      assert :ok = Testing.assert_published("widget.created")
    end

    test "raises ExUnit.AssertionError when no match found" do
      {:ok, _} = Outbox.publish("widget.created", %{"id" => "w_1"})

      assert_raise ExUnit.AssertionError, fn ->
        Testing.assert_published("widget.created", %{"id" => "missing"})
      end
    end

    test "raises with recent-events listing when nothing matches at all" do
      {:ok, _} = Outbox.publish("other.event", %{"id" => "z"})

      try do
        Testing.assert_published("widget.created", %{"id" => "missing"})
        flunk("expected assertion to raise")
      rescue
        e in ExUnit.AssertionError ->
          assert e.message =~ "widget.created"
          assert e.message =~ "other.event"
      end
    end
  end

  describe "with_sync_dispatch/1" do
    test "runs subscribers synchronously before returning" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, subscribers: [EchoSubscriber])

      Testing.with_sync_dispatch(fn ->
        {:ok, _} = Outbox.publish("echo.event", %{"id" => "e_1"})
      end)

      assert_received {:echo, "echo.event", %{"id" => "e_1"}, _meta}
    end

    test "returns whatever the wrapped function returns" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, subscribers: [])
      result = Testing.with_sync_dispatch(fn -> :return_value end)
      assert result == :return_value
    end

    test "subscriber meta carries the event context" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, subscribers: [EchoSubscriber])

      Testing.with_sync_dispatch(fn ->
        {:ok, _} = Outbox.publish("echo.event", %{"id" => "e_1"}, context: %{"actor_id" => "u1"})
      end)

      assert_received {:echo, "echo.event", %{"id" => "e_1"}, meta}
      assert meta.context == %{"actor_id" => "u1"}
    end
  end
end

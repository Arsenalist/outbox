defmodule Outbox.RegistryTest do
  use ExUnit.Case, async: false

  alias Outbox.Registry

  alias Outbox.TestSubscribers.{
    CatchAllSubscriber,
    EchoSubscriber,
    OkSubscriber,
    PrefixSubscriber,
    RaisingSubscriber
  }

  setup do
    prev = Application.get_env(:outbox, Outbox)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:outbox, Outbox, prev),
        else: Application.delete_env(:outbox, Outbox)
    end)

    :ok
  end

  describe "lookup/1" do
    test "returns empty list when no subscribers configured" do
      Application.put_env(:outbox, Outbox, subscribers: [])
      assert Registry.lookup("anything") == []
    end

    test "returns matching subscriber" do
      Application.put_env(:outbox, Outbox, subscribers: [EchoSubscriber])
      assert Registry.lookup("echo.event") == [EchoSubscriber]
    end

    test "returns multiple subscribers listening for the same event" do
      Application.put_env(:outbox, Outbox, subscribers: [EchoSubscriber, OkSubscriber])
      assert Registry.lookup("shared.event") == [EchoSubscriber, OkSubscriber]
    end

    test "returns empty list when no subscriber listens for the event" do
      Application.put_env(:outbox, Outbox, subscribers: [EchoSubscriber, RaisingSubscriber])
      assert Registry.lookup("nobody.cares") == []
    end

    test "preserves subscriber order from config" do
      Application.put_env(:outbox, Outbox, subscribers: [OkSubscriber, EchoSubscriber])
      assert Registry.lookup("shared.event") == [OkSubscriber, EchoSubscriber]
    end
  end

  describe "lookup/1 — pattern matching" do
    test "\"*\" matches any event name" do
      Application.put_env(:outbox, Outbox, subscribers: [CatchAllSubscriber])
      assert Registry.lookup("anything.at.all") == [CatchAllSubscriber]
      assert Registry.lookup("x") == [CatchAllSubscriber]
    end

    test "prefix wildcard matches names under the prefix" do
      Application.put_env(:outbox, Outbox, subscribers: [PrefixSubscriber])
      assert Registry.lookup("order.refunded") == [PrefixSubscriber]
      assert Registry.lookup("order.placed") == [PrefixSubscriber]
    end

    test "prefix wildcard matches nested segments" do
      Application.put_env(:outbox, Outbox, subscribers: [PrefixSubscriber])
      assert Registry.lookup("order.line.added") == [PrefixSubscriber]
    end

    test "prefix wildcard does not match the bare prefix or a longer prefix word" do
      Application.put_env(:outbox, Outbox, subscribers: [PrefixSubscriber])
      assert Registry.lookup("order") == []
      assert Registry.lookup("ordering.created") == []
    end

    test "prefix wildcard does not match an unrelated entity" do
      Application.put_env(:outbox, Outbox, subscribers: [PrefixSubscriber])
      assert Registry.lookup("refund.created") == []
    end

    test "an exact pattern alongside a wildcard still matches" do
      Application.put_env(:outbox, Outbox, subscribers: [PrefixSubscriber])
      assert Registry.lookup("discount.created") == [PrefixSubscriber]
    end

    test "a subscriber matching via multiple patterns appears only once" do
      Application.put_env(:outbox, Outbox, subscribers: [CatchAllSubscriber, PrefixSubscriber])
      # order.refunded matches CatchAll's "*" AND Prefix's "order.*"
      assert Registry.lookup("order.refunded") == [CatchAllSubscriber, PrefixSubscriber]
    end
  end

  describe "subscribers/0" do
    test "returns the full configured list" do
      Application.put_env(:outbox, Outbox, subscribers: [EchoSubscriber, OkSubscriber])
      assert Registry.subscribers() == [EchoSubscriber, OkSubscriber]
    end
  end
end

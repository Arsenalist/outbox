defmodule Outbox.RegistryTest do
  use ExUnit.Case, async: false

  alias Outbox.Registry
  alias Outbox.TestSubscribers.{EchoSubscriber, OkSubscriber, RaisingSubscriber}

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

  describe "subscribers/0" do
    test "returns the full configured list" do
      Application.put_env(:outbox, Outbox, subscribers: [EchoSubscriber, OkSubscriber])
      assert Registry.subscribers() == [EchoSubscriber, OkSubscriber]
    end
  end
end

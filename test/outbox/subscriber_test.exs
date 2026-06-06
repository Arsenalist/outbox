defmodule Outbox.SubscriberTest do
  use ExUnit.Case, async: true

  test "use Outbox.Subscriber declares the behaviour" do
    defmodule MySub do
      use Outbox.Subscriber

      def events, do: ["foo.bar"]
      def handle_event(_name, _payload, _meta), do: :ok
    end

    assert Outbox.Subscriber in MySub.module_info(:attributes)[:behaviour]
  end

  test "behaviour declares events/0 and handle_event/3 callbacks" do
    callbacks = Outbox.Subscriber.behaviour_info(:callbacks)
    assert {:events, 0} in callbacks
    assert {:handle_event, 3} in callbacks
  end
end

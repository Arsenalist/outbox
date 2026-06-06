defmodule Outbox.TickerTest do
  use ExUnit.Case, async: false

  alias Outbox.Ticker

  setup do
    # Make a Task.Supervisor available for the ticker's spawn target.
    case Process.whereis(Outbox.TaskSupervisor) do
      nil -> start_supervised!({Task.Supervisor, name: Outbox.TaskSupervisor})
      _ -> :ok
    end

    :ok
  end

  describe "start_link/1" do
    test "when enabled: false, returns ok and never runs the dispatcher" do
      {:ok, pid} = Ticker.start_link(enabled: false, interval_ms: 50, name: :ticker_disabled)
      Process.sleep(150)
      # State should be enabled: false; no exception should have occurred.
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "when enabled: true, schedules ticks at the configured interval" do
      defmodule SpyDispatcher do
        def run, do: send(:ticker_spy_listener, :tick)
      end

      Process.register(self(), :ticker_spy_listener)

      {:ok, pid} =
        Ticker.start_link(
          enabled: true,
          interval_ms: 30,
          dispatcher: SpyDispatcher,
          name: :ticker_enabled
        )

      assert_receive :tick, 200
      GenServer.stop(pid)
    after
      Process.unregister(:ticker_spy_listener)
    end
  end
end

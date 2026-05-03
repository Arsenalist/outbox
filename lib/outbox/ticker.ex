defmodule Amplify.DomainEvents.Ticker do
  @moduledoc """
  Periodically runs `Amplify.DomainEvents.Dispatcher.run/0` in a
  supervised Task.

  Free Oban's Cron plugin is minute-granularity, but the bus needs
  sub-minute dispatch latency. This GenServer ticks every `interval_ms`
  (default 5000) and spawns a Task on `Amplify.TaskSupervisor` to do
  the dispatch work.

  Why a Task (not an Oban job):
    * No per-tick Oban telemetry log noise.
    * The dispatcher is internal infrastructure — Oban's retry/DLQ
      machinery doesn't add value here. The next tick (5s later) is
      the retry.
    * Task crashes are isolated from the Ticker (supervised).

  Concurrent overlap is safe: `FOR UPDATE SKIP LOCKED` in the dispatcher
  ensures two simultaneous runs never claim the same event.

  Disabled in test (set `enabled: false`); tests drive dispatch
  explicitly via `Amplify.DomainEvents.Test.with_sync_dispatch/1`.
  """

  use GenServer

  alias Amplify.DomainEvents.Dispatcher

  @default_interval_ms 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    enabled? = Keyword.get(opts, :enabled, true)

    if enabled? do
      schedule_tick(interval)
      {:ok, %{interval: interval, enabled: true}}
    else
      {:ok, %{interval: interval, enabled: false}}
    end
  end

  @impl true
  def handle_info(:tick, %{interval: interval} = state) do
    Task.Supervisor.start_child(Amplify.TaskSupervisor, fn -> Dispatcher.run() end)
    schedule_tick(interval)
    {:noreply, state}
  end

  defp schedule_tick(interval), do: Process.send_after(self(), :tick, interval)
end

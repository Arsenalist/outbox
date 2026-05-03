defmodule Amplify.DomainEvents.Ticker do
  @moduledoc """
  Periodically enqueues `Amplify.DomainEvents.Dispatcher` jobs.

  Free Oban's Cron plugin is minute-granularity, but the bus needs
  sub-minute dispatch latency for the search-indexing use case. This
  GenServer ticks every `interval_ms` (default 5000) and enqueues a
  dispatcher job into the `:domain_events_dispatch` queue.

  The dispatcher itself is idempotent (it does nothing when the outbox
  is empty), so over-enqueuing is harmless.

  Disabled in test (Oban testing mode is `:manual`); tests drive
  dispatch explicitly via `Amplify.DomainEvents.Test.with_sync_dispatch/1`.
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
    Dispatcher.new(%{}) |> Oban.insert()
    schedule_tick(interval)
    {:noreply, state}
  end

  defp schedule_tick(interval), do: Process.send_after(self(), :tick, interval)
end

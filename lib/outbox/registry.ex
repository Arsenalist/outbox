defmodule Outbox.Registry do
  @moduledoc """
  Resolves event names to subscriber modules.

  Reads subscribers from `Outbox.Config.subscribers/0` on every lookup.
  No GenServer, no ETS cache — the dispatcher polls every 5 seconds, so
  the lookup happens at most a few times per second per node; caching
  would not be a meaningful optimization at this volume.

  Trivial-by-design also means tests can override the subscriber list
  with `Application.put_env/3` without restarting the application.
  """

  @doc """
  Returns the list of subscriber modules listening for the given event
  name. Returns `[]` if no subscribers match.
  """
  @spec lookup(String.t()) :: [module()]
  def lookup(event_name) when is_binary(event_name) do
    for subscriber <- subscribers(),
        event_name in subscriber.events() do
      subscriber
    end
  end

  @doc "Returns the full list of registered subscriber modules."
  @spec subscribers() :: [module()]
  def subscribers, do: Outbox.Config.subscribers()
end

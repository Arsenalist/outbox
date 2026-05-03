defmodule Amplify.DomainEvents.Registry do
  @moduledoc """
  Resolves event names to subscriber modules.

  Reads subscriber modules from
  `Application.get_env(:amplify, Amplify.DomainEvents)[:subscribers]`
  on every lookup. This keeps the implementation trivial (no GenServer,
  no ETS) and lets tests override the subscriber list with
  `Application.put_env/3` without restarting the application.

  The dispatcher polls every 5 seconds, so the lookup happens at most a
  few times per second per node — caching would not be a meaningful
  optimization at this volume.
  """

  @app :amplify

  @doc """
  Returns the list of subscriber modules listening for the given event name.
  Returns an empty list if no subscribers are registered for the event.
  """
  @spec lookup(String.t()) :: [module()]
  def lookup(event_name) when is_binary(event_name) do
    for subscriber <- subscribers(),
        event_name in subscriber.events() do
      subscriber
    end
  end

  @doc """
  Returns the full list of registered subscriber modules.
  """
  @spec subscribers() :: [module()]
  def subscribers do
    Application.get_env(@app, Amplify.DomainEvents, [])
    |> Keyword.get(:subscribers, [])
  end
end

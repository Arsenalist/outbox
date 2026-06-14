defmodule Outbox.TestSubscribers do
  @moduledoc "Support subscriber modules used by dispatcher, job, registry, and broadcaster tests."

  defmodule EchoSubscriber do
    @moduledoc "Stores each received event in a process-dictionary-backed ETS table for assertions."
    @behaviour Outbox.Subscriber

    @impl true
    def events, do: ["echo.event", "shared.event"]

    @impl true
    def handle_event(name, payload, meta) do
      send(self(), {:echo, name, payload, meta})
      :ok
    end
  end

  defmodule OkSubscriber do
    @moduledoc "Always returns :ok."
    @behaviour Outbox.Subscriber

    @impl true
    def events, do: ["ok.event", "shared.event"]

    @impl true
    def handle_event(_name, _payload, _meta), do: :ok
  end

  defmodule RaisingSubscriber do
    @moduledoc "Always raises a RuntimeError."
    @behaviour Outbox.Subscriber

    @impl true
    def events, do: ["raising.event"]

    @impl true
    def handle_event(_name, _payload, _meta), do: raise("boom")
  end

  defmodule ErrorReturningSubscriber do
    @moduledoc "Always returns {:error, :nope}."
    @behaviour Outbox.Subscriber

    @impl true
    def events, do: ["error.event"]

    @impl true
    def handle_event(_name, _payload, _meta), do: {:error, :nope}
  end

  defmodule PrefixSubscriber do
    @moduledoc "Listens for a prefix wildcard plus an exact name."
    @behaviour Outbox.Subscriber

    @impl true
    def events, do: ["order.*", "discount.created"]

    @impl true
    def handle_event(_name, _payload, _meta), do: :ok
  end

  defmodule CatchAllSubscriber do
    @moduledoc "Listens for everything via the \"*\" pattern."
    @behaviour Outbox.Subscriber

    @impl true
    def events, do: ["*"]

    @impl true
    def handle_event(_name, _payload, _meta), do: :ok
  end
end

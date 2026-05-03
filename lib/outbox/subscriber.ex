defmodule Amplify.DomainEvents.Subscriber do
  @moduledoc """
  Behaviour for modules that react to domain events from the bus.

  ## Implementing a subscriber

      defmodule MyApp.MySubscriber do
        use Amplify.DomainEvents.Subscriber

        @impl true
        def events, do: ["product.created", "product.updated"]

        @impl true
        def handle_event("product.created", %{"id" => id}, _meta) do
          # do work
          :ok
        end

        def handle_event("product.updated", %{"id" => id}, _meta) do
          # do work
          :ok
        end
      end

  Then register it in `config/config.exs`:

      config :amplify, Amplify.DomainEvents,
        subscribers: [MyApp.MySubscriber, ...]

  ## Delivery contract

  Each subscriber receives each event **at least once**. Implementations
  MUST be idempotent. The `meta` map carries `:event_id` (UUIDv7) and
  `:inserted_at` (DateTime) so subscribers needing strict deduplication
  can persist a "processed event ids" record.

  Returning `:ok` marks the Oban job as completed. Returning
  `{:error, reason}` or raising triggers Oban's retry/backoff machinery.
  """

  @type meta :: %{
          required(:event_id) => String.t(),
          required(:inserted_at) => DateTime.t()
        }

  @callback events() :: [String.t()]
  @callback handle_event(name :: String.t(), payload :: map(), meta :: meta()) ::
              :ok | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Amplify.DomainEvents.Subscriber
    end
  end
end

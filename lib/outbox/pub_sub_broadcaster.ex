defmodule Amplify.DomainEvents.PubSubBroadcaster do
  @moduledoc """
  Built-in subscriber that re-broadcasts every domain event from the v1
  catalog through `Phoenix.PubSub` on the topic `"domain_events"`.

  This enables LiveView and other in-process consumers to react to
  domain events without registering as a formal `Subscriber`. Subscribe
  with:

      Phoenix.PubSub.subscribe(Amplify.PubSub, "domain_events")

  Listeners receive messages of the form:

      {:domain_event, name :: String.t(), payload :: map(), meta :: map()}

  The broadcaster also serves as a smoke test for the bus: shipping it
  alongside the bus itself proves the public API works end-to-end with
  a real consumer from day one.
  """

  use Amplify.DomainEvents.Subscriber

  @v1_catalog [
    "product.created",
    "product.updated",
    "product.deleted",
    "variant.created",
    "variant.updated",
    "variant.deleted"
  ]

  @impl true
  def events, do: @v1_catalog

  @impl true
  def handle_event(name, payload, meta) do
    Phoenix.PubSub.broadcast(
      Amplify.PubSub,
      "domain_events",
      {:domain_event, name, payload, meta}
    )

    :ok
  end
end

defmodule Outbox.Testing do
  @moduledoc """
  Test helpers for asserting domain-event publication and exercising
  subscribers synchronously.

  Import in your test:

      defmodule MyTest do
        use ExUnit.Case
        import Outbox.Testing

        test "create_widget publishes widget.created" do
          MyContext.create_widget(...)
          assert_published("widget.created", %{"id" => "expected_id"})
        end

        test "subscriber side-effect runs end-to-end" do
          with_sync_dispatch(fn ->
            MyContext.create_widget(...)
          end)
          assert MyExternalSystem.was_called?()
        end
      end
  """

  import Ecto.Query
  import ExUnit.Assertions

  alias Outbox.OutboxEvent

  @doc """
  Asserts that an event with the given name was published during the
  test, optionally matching a subset of payload keys.

  ## Examples

      assert_published("product.created")
      assert_published("product.created", %{"id" => "p_abc"})
      assert_published("variant.updated", %{"id" => "v_xyz"})
  """
  @spec assert_published(String.t(), map()) :: :ok | no_return()
  def assert_published(name, payload_match \\ %{})
      when is_binary(name) and is_map(payload_match) do
    repo = Outbox.Config.repo()

    matches =
      from(e in OutboxEvent, where: e.name == ^name)
      |> repo.all()
      |> Enum.filter(&payload_matches?(&1.payload, payload_match))

    if matches == [] do
      recent =
        from(e in OutboxEvent, order_by: [desc: e.id], limit: 5, select: {e.name, e.payload})
        |> repo.all()

      flunk("""
      Expected an outbox event with name #{inspect(name)} matching payload #{inspect(payload_match)}.

      No matching event was found.

      Most recent published events (up to 5):
      #{Enum.map_join(recent, "\n", fn {n, p} -> "  - #{inspect(n)} #{inspect(p)}" end)}
      """)
    end

    :ok
  end

  defp payload_matches?(actual, expected) when is_map(actual) and is_map(expected) do
    Enum.all?(expected, fn {k, v} -> Map.get(actual, k) == v end)
  end

  @doc """
  Runs the given function and synchronously dispatches every event
  published during it, then drains the `outbox` queue on the
  `Outbox.Config.oban/0` instance so all registered subscribers run
  before returning.
  """
  @spec with_sync_dispatch((-> any())) :: any()
  def with_sync_dispatch(fun) when is_function(fun, 0) do
    result = fun.()

    Outbox.Dispatcher.run()
    Oban.drain_queue(Outbox.Config.oban(), queue: :outbox)

    result
  end
end

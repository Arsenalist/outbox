defmodule Outbox.SubscriberJobTest do
  use Outbox.DataCase, async: false

  alias Outbox.{OutboxEvent, SubscriberJob}

  defp insert_event!(attrs \\ %{}) do
    defaults = %{name: "echo.event", payload: %{"id" => "x"}}

    %OutboxEvent{}
    |> OutboxEvent.changeset(Map.merge(defaults, attrs))
    |> TestRepo.insert!()
  end

  describe "perform/1" do
    test "calls subscriber's handle_event/3 and returns :ok for ok-subscriber" do
      event = insert_event!()

      args = %{
        "event_id" => event.id,
        "subscriber" => "Elixir.Outbox.TestSubscribers.OkSubscriber"
      }

      assert :ok = perform_job(SubscriberJob, args)
    end

    test "echoes received name/payload/meta to caller" do
      event = insert_event!(%{name: "echo.event", payload: %{"k" => "v"}})

      args = %{
        "event_id" => event.id,
        "subscriber" => "Elixir.Outbox.TestSubscribers.EchoSubscriber"
      }

      perform_job(SubscriberJob, args)

      assert_received {:echo, "echo.event", %{"k" => "v"}, meta}
      assert meta.event_id == event.id
      assert %DateTime{} = meta.inserted_at
    end

    test "propagates {:error, _} from subscriber" do
      event = insert_event!(%{name: "error.event"})

      args = %{
        "event_id" => event.id,
        "subscriber" => "Elixir.Outbox.TestSubscribers.ErrorReturningSubscriber"
      }

      assert {:error, :nope} = perform_job(SubscriberJob, args)
    end

    test "raised exceptions propagate to Oban's retry machinery" do
      event = insert_event!(%{name: "raising.event"})

      args = %{
        "event_id" => event.id,
        "subscriber" => "Elixir.Outbox.TestSubscribers.RaisingSubscriber"
      }

      assert_raise RuntimeError, "boom", fn ->
        perform_job(SubscriberJob, args)
      end
    end

    test "discards when outbox event row missing" do
      args = %{
        "event_id" => Ecto.UUID.generate(),
        "subscriber" => "Elixir.Outbox.TestSubscribers.OkSubscriber"
      }

      assert {:discard, msg} = perform_job(SubscriberJob, args)
      assert msg =~ "outbox event not found"
    end

    test "discards when subscriber module name is not loadable" do
      event = insert_event!()

      args = %{"event_id" => event.id, "subscriber" => "Elixir.DoesNotExist.AtAll"}

      # R-M2: ensures resolver fails gracefully rather than crashing the job.
      assert {:discard, msg} = perform_job(SubscriberJob, args)
      assert msg =~ "subscriber module not loaded"
    end

    test "R-M2: cold-start — module loadable but not yet referenced still resolves" do
      event = insert_event!()
      # Ensure the module is loaded even if no other test has referenced it yet.
      Code.ensure_loaded!(Outbox.TestSubscribers.OkSubscriber)

      args = %{
        "event_id" => event.id,
        "subscriber" => "Elixir.Outbox.TestSubscribers.OkSubscriber"
      }

      assert :ok = perform_job(SubscriberJob, args)
    end
  end

  # Manual job runner — bypasses Oban dispatch entirely.
  defp perform_job(worker, args) do
    job = %Oban.Job{args: args, attempt: 1, max_attempts: 5, queue: "outbox"}
    worker.perform(job)
  end
end

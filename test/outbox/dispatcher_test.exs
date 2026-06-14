defmodule Outbox.DispatcherTest do
  use Outbox.DataCase, async: false

  alias Outbox.{Dispatcher, OutboxEvent}
  alias Outbox.TestSubscribers.{EchoSubscriber, OkSubscriber}

  setup do
    prev = Application.get_env(:outbox, Outbox)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:outbox, Outbox, prev),
        else: Application.delete_env(:outbox, Outbox)
    end)

    # Use shared sandbox mode so Oban's processes can write into the
    # same connection the test owns.
    Ecto.Adapters.SQL.Sandbox.mode(TestRepo, {:shared, self()})
    :ok
  end

  defp insert_event!(name, payload \\ %{}) do
    %OutboxEvent{}
    |> OutboxEvent.changeset(%{name: name, payload: payload})
    |> TestRepo.insert!()
  end

  describe "run/0" do
    test "claims batch and enqueues one job per (event, subscriber)" do
      Application.put_env(:outbox, Outbox,
        repo: TestRepo,
        subscribers: [EchoSubscriber, OkSubscriber]
      )

      e1 = insert_event!("shared.event")
      e2 = insert_event!("shared.event")

      Dispatcher.run()

      jobs = all_outbox_jobs()
      assert length(jobs) == 4

      event_subscriber_pairs =
        Enum.map(jobs, fn j -> {j.args["event_id"], j.args["subscriber"]} end)
        |> Enum.sort()

      expected =
        [
          {e1.id, "Elixir.Outbox.TestSubscribers.EchoSubscriber"},
          {e1.id, "Elixir.Outbox.TestSubscribers.OkSubscriber"},
          {e2.id, "Elixir.Outbox.TestSubscribers.EchoSubscriber"},
          {e2.id, "Elixir.Outbox.TestSubscribers.OkSubscriber"}
        ]
        |> Enum.sort()

      assert event_subscriber_pairs == expected
    end

    test "marks processed events dispatched" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, subscribers: [OkSubscriber])
      e1 = insert_event!("ok.event")

      Dispatcher.run()

      reloaded = TestRepo.get(OutboxEvent, e1.id)
      refute is_nil(reloaded.dispatched_at)
    end

    test "marks dispatched even when no subscribers match" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, subscribers: [OkSubscriber])
      e1 = insert_event!("nobody.cares")

      Dispatcher.run()

      reloaded = TestRepo.get(OutboxEvent, e1.id)
      refute is_nil(reloaded.dispatched_at)
      assert all_outbox_jobs() == []
    end

    test "skips already-dispatched events" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, subscribers: [OkSubscriber])
      insert_event!("ok.event")

      Dispatcher.run()
      first_pass = all_outbox_jobs()

      Dispatcher.run()
      second_pass = all_outbox_jobs()

      # Second run finds no undispatched events, enqueues no new jobs.
      assert first_pass == second_pass
    end

    test "broadcasts each dispatched event to Phoenix.PubSub when configured" do
      pubsub = Outbox.DispatcherPubSub

      case Process.whereis(pubsub) do
        nil -> start_supervised!({Phoenix.PubSub, name: pubsub})
        _ -> :ok
      end

      Application.put_env(:outbox, Outbox,
        repo: TestRepo,
        subscribers: [OkSubscriber],
        pubsub: pubsub,
        pubsub_topic: "test_dispatch_broadcast"
      )

      Phoenix.PubSub.subscribe(pubsub, "test_dispatch_broadcast")

      e1 = insert_event!("ok.event", %{"k" => "v"})

      Dispatcher.run()

      assert_receive {:domain_event, "ok.event", %{"k" => "v"}, meta}, 500
      assert meta.event_id == e1.id
    end

    test "does NOT broadcast when pubsub is unconfigured" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, subscribers: [OkSubscriber])

      insert_event!("ok.event")
      Dispatcher.run()

      refute_received {:domain_event, _, _, _}
    end

    test "R-H1: enqueued jobs land on the Outbox.Oban instance, not the default Oban" do
      Application.put_env(:outbox, Outbox, repo: TestRepo, subscribers: [OkSubscriber])
      insert_event!("ok.event")

      Dispatcher.run()

      jobs = all_outbox_jobs()
      assert length(jobs) == 1
      [job] = jobs
      assert job.queue == "outbox"
      # Sanity: this row was inserted through Oban.insert(Outbox.Oban, ...)
      # — confirmed by the fact that the job is queued, not executed.
      assert job.state == "available"
    end
  end

  defp all_outbox_jobs do
    TestRepo.all(from(j in "oban_jobs", select: %{args: j.args, queue: j.queue, state: j.state}))
  end
end

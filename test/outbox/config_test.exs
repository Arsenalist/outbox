defmodule Outbox.ConfigTest do
  use ExUnit.Case, async: false

  alias Outbox.Config

  setup do
    prev = Application.get_env(:outbox, Outbox)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:outbox, Outbox, prev),
        else: Application.delete_env(:outbox, Outbox)
    end)

    :ok
  end

  describe "repo/0" do
    test "returns the configured repo" do
      Application.put_env(:outbox, Outbox, repo: Outbox.TestRepo)
      assert Config.repo() == Outbox.TestRepo
    end

    test "raises informatively when unset" do
      Application.delete_env(:outbox, Outbox)

      assert_raise RuntimeError, ~r/config :outbox, Outbox,\s+repo:/, fn ->
        Config.repo()
      end
    end

    test "R-H4: reads at call time (no compile-time freeze)" do
      Application.put_env(:outbox, Outbox, repo: FirstRepo)
      assert Config.repo() == FirstRepo

      Application.put_env(:outbox, Outbox, repo: SecondRepo)
      assert Config.repo() == SecondRepo
    end
  end

  describe "subscribers/0" do
    test "defaults to []" do
      Application.put_env(:outbox, Outbox, [])
      assert Config.subscribers() == []
    end

    test "returns the configured list" do
      Application.put_env(:outbox, Outbox, subscribers: [FakeOne, FakeTwo])
      assert Config.subscribers() == [FakeOne, FakeTwo]
    end
  end

  describe "retention_days/0" do
    test "defaults to 30" do
      Application.put_env(:outbox, Outbox, [])
      assert Config.retention_days() == 30
    end

    test "honors override" do
      Application.put_env(:outbox, Outbox, retention_days: 7)
      assert Config.retention_days() == 7
    end
  end

  describe "oban/0" do
    test "defaults to Outbox.Oban" do
      Application.put_env(:outbox, Outbox, [])
      assert Config.oban() == Outbox.Oban
    end

    test "honors override" do
      Application.put_env(:outbox, Outbox, oban: MyApp.Oban)
      assert Config.oban() == MyApp.Oban
    end
  end

  describe "pubsub/0" do
    test "defaults to nil (broadcasting disabled)" do
      Application.put_env(:outbox, Outbox, [])
      assert Config.pubsub() == nil
    end

    test "returns the configured pubsub server name" do
      Application.put_env(:outbox, Outbox, pubsub: MyApp.PubSub)
      assert Config.pubsub() == MyApp.PubSub
    end
  end

  describe "pubsub_topic/0" do
    test "defaults to \"domain_events\"" do
      Application.put_env(:outbox, Outbox, [])
      assert Config.pubsub_topic() == "domain_events"
    end

    test "honors override" do
      Application.put_env(:outbox, Outbox, pubsub_topic: "events")
      assert Config.pubsub_topic() == "events"
    end
  end
end

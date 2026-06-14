defmodule Outbox.IdempotencyTest do
  use Outbox.DataCase, async: false

  alias Outbox.{ConsumedEvent, Idempotency}

  defp uuid, do: Ecto.UUID.generate()

  describe "run_once/3" do
    test "runs the function on first call and records consumption" do
      id = uuid()

      assert :ok =
               Idempotency.run_once("audit", id, fn ->
                 send(self(), :ran)
                 :ok
               end)

      assert_received :ran
      assert [_] = TestRepo.all(ConsumedEvent)
    end

    test "skips the function on a duplicate (same consumer + event_id)" do
      id = uuid()
      assert :ok = Idempotency.run_once("audit", id, fn -> :ok end)

      assert {:ok, :already_processed} =
               Idempotency.run_once("audit", id, fn ->
                 send(self(), :ran_again)
                 :ok
               end)

      refute_received :ran_again
    end

    test "passes the function's {:ok, value} through" do
      assert {:ok, 42} = Idempotency.run_once("c", uuid(), fn -> {:ok, 42} end)
    end

    test "the same event_id is processed once per consumer" do
      id = uuid()
      assert :ok = Idempotency.run_once("audit", id, fn -> :ok end)
      assert :ok = Idempotency.run_once("posthog", id, fn -> :ok end)
      assert length(TestRepo.all(ConsumedEvent)) == 2
    end

    test "rolls back the claim when the function returns {:error, _} so a retry re-runs" do
      id = uuid()
      assert {:error, :boom} = Idempotency.run_once("c", id, fn -> {:error, :boom} end)
      assert [] = TestRepo.all(ConsumedEvent)

      assert :ok =
               Idempotency.run_once("c", id, fn ->
                 send(self(), :retried)
                 :ok
               end)

      assert_received :retried
    end

    test "rolls back the claim when the function raises" do
      id = uuid()

      assert_raise RuntimeError, fn ->
        Idempotency.run_once("c", id, fn -> raise "boom" end)
      end

      assert [] = TestRepo.all(ConsumedEvent)
    end
  end
end

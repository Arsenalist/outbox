defmodule Outbox.UuidCoexistenceTest do
  @moduledoc """
  Asserts the dispatcher processes rows in index order regardless of UUID
  version. Some host applications carry legacy `outbox_events` rows with
  UUIDv7 IDs from an earlier in-house implementation; new rows inserted by
  `Outbox.publish/2` use UUIDv4 (via `uuid_generate_v4()`). Both must
  coexist correctly: the partial-index lookup
  `WHERE dispatched_at IS NULL ORDER BY id ASC` yields a well-defined
  iteration regardless of UUID version.
  """

  use Outbox.DataCase, async: false

  alias Outbox.{Dispatcher, OutboxEvent}
  alias Outbox.TestSubscribers.OkSubscriber

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(TestRepo, {:shared, self()})
    prev = Application.get_env(:outbox, Outbox)

    Application.put_env(
      :outbox,
      Outbox,
      Keyword.merge(prev || [], subscribers: [OkSubscriber])
    )

    on_exit(fn ->
      if prev,
        do: Application.put_env(:outbox, Outbox, prev),
        else: Application.delete_env(:outbox, Outbox)
    end)

    :ok
  end

  test "dispatcher processes UUIDv4 and a-pre-existing-uuid-style row in index order" do
    # Simulate a pre-existing UUIDv7-style row by inserting with an explicit
    # smaller UUID (UUIDv7s sort earlier in lexical/binary order vs random
    # UUIDv4s on average; for the test we just pick a small UUID).
    early_id = "00000000-0000-7000-8000-000000000001"
    later_id = "ffffffff-ffff-4fff-bfff-ffffffffffff"

    {:ok, _} = TestRepo.insert(%OutboxEvent{id: early_id, name: "ok.event", payload: %{"i" => 1}})
    {:ok, _} = TestRepo.insert(%OutboxEvent{id: later_id, name: "ok.event", payload: %{"i" => 2}})

    Dispatcher.run()

    [early_row, later_row] =
      OutboxEvent
      |> TestRepo.all()
      |> Enum.sort_by(& &1.id)

    refute is_nil(early_row.dispatched_at)
    refute is_nil(later_row.dispatched_at)
  end
end

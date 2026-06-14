defmodule Outbox.OutboxEventTest do
  use ExUnit.Case, async: true

  alias Outbox.OutboxEvent

  describe "changeset/2" do
    test "accepts valid attrs" do
      changeset =
        OutboxEvent.changeset(%OutboxEvent{}, %{
          name: "product.created",
          payload: %{"id" => "p_123"}
        })

      assert changeset.valid?
    end

    test "rejects blank (whitespace-only) name" do
      changeset = OutboxEvent.changeset(%OutboxEvent{}, %{name: "  ", payload: %{}})
      refute changeset.valid?
      # validate_required catches blank-after-trim with "can't be blank"
      assert changeset.errors[:name] != nil
    end

    test "rejects missing name" do
      changeset = OutboxEvent.changeset(%OutboxEvent{}, %{payload: %{}})
      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:name]
    end

    test "rejects non-binary name (cast failure)" do
      changeset = OutboxEvent.changeset(%OutboxEvent{}, %{name: 123, payload: %{}})
      refute changeset.valid?
      assert changeset.errors[:name] != nil
    end

    test "rejects missing payload" do
      changeset = OutboxEvent.changeset(%OutboxEvent{}, %{name: "foo.bar"})
      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:payload]
    end

    test "rejects non-map payload (cast failure)" do
      changeset = OutboxEvent.changeset(%OutboxEvent{}, %{name: "foo.bar", payload: "not-a-map"})
      refute changeset.valid?
      assert changeset.errors[:payload] != nil
    end
  end

  describe "schema" do
    test "binary_id primary key" do
      assert OutboxEvent.__schema__(:primary_key) == [:id]
      assert OutboxEvent.__schema__(:type, :id) == :binary_id
    end

    test "fields are name, payload, context, inserted_at, dispatched_at" do
      assert OutboxEvent.__schema__(:fields) == [
               :id,
               :name,
               :payload,
               :context,
               :dispatched_at,
               :inserted_at
             ]
    end

    test "changeset casts context" do
      cs =
        OutboxEvent.changeset(%OutboxEvent{}, %{name: "a.b", payload: %{}, context: %{"x" => "1"}})

      assert cs.valid?
      assert Ecto.Changeset.get_field(cs, :context) == %{"x" => "1"}
    end

    test "no updated_at timestamp" do
      refute :updated_at in OutboxEvent.__schema__(:fields)
    end
  end
end

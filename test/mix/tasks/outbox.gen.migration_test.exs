defmodule Mix.Tasks.Outbox.Gen.MigrationTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Outbox.Gen.Migration

  setup do
    tmp =
      Path.join(System.tmp_dir!(), "outbox_migration_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  describe "render/1" do
    test "produces a migration body matching the canonical template" do
      body =
        Migration.render(
          prefix: "public",
          module_name: "Outbox.Repo.Migrations.CreateOutboxEventsTable"
        )

      assert body =~ "create table(:outbox_events"
      assert body =~ "primary_key: false"
      assert body =~ "add :id, :uuid, primary_key: true"
      assert body =~ "uuid_generate_v4()"
      assert body =~ "create index(:outbox_events"
      assert body =~ "where: \"dispatched_at IS NULL\""
    end

    test "honors --prefix option" do
      body = Migration.render(prefix: "myschema", module_name: "X.Y")
      assert body =~ ~s|prefix: "myschema"|
    end
  end

  describe "write_migration/3" do
    test "writes a timestamped file into the given directory", %{tmp: tmp} do
      path = Migration.write_migration(tmp, "public", fn -> "20260606999999" end)
      assert File.exists?(path)
      assert Path.basename(path) =~ ~r/^20260606999999_create_outbox_events_table\.exs$/
    end
  end
end

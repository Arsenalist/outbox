defmodule Mix.Tasks.Outbox.Gen.Migration do
  @shortdoc "Generates the outbox_events migration in the host's migrations directory"

  @moduledoc """
  Generates the `outbox_events` table migration in the host's
  `priv/repo/migrations/` directory.

  ## Examples

      mix outbox.gen.migration
      mix outbox.gen.migration --prefix tenant

  ## Options

    * `--prefix` - Postgres schema prefix to use. Defaults to `"public"`.
    * `--repo` - the Repo to introspect for the migrations path. Defaults
      to the first repo in `:ecto_repos` config.
  """

  use Mix.Task

  @switches [prefix: :string, repo: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, switches: @switches)
    prefix = Keyword.get(opts, :prefix, "public")

    migrations_path = resolve_migrations_path(opts)
    File.mkdir_p!(migrations_path)

    path = write_migration(migrations_path, prefix, &default_timestamp/0)
    Mix.shell().info("* creating #{Path.relative_to_cwd(path)}")
    path
  end

  @doc """
  Renders the migration body. Exposed so the generator's test can
  verify the canonical template without writing to disk.
  """
  @spec render(keyword()) :: String.t()
  def render(opts) do
    module_name = Keyword.fetch!(opts, :module_name)
    prefix = Keyword.get(opts, :prefix, "public")

    table_opts =
      if prefix == "public",
        do: "primary_key: false",
        else: "primary_key: false, prefix: \"#{prefix}\""

    index_prefix = if prefix == "public", do: "", else: "prefix: \"#{prefix}\", "

    """
    defmodule #{module_name} do
      use Ecto.Migration

      def change do
        execute("CREATE EXTENSION IF NOT EXISTS \\"uuid-ossp\\"", "")

        create table(:outbox_events, #{table_opts}) do
          add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
          add :name, :text, null: false
          add :payload, :jsonb, null: false
          add :context, :jsonb, null: false, default: fragment("'{}'::jsonb")
          add :inserted_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
          add :dispatched_at, :utc_datetime_usec
        end

        create index(:outbox_events, [:id],
                 #{index_prefix}where: "dispatched_at IS NULL",
                 name: :outbox_events_undispatched_idx
               )

        create table(:outbox_consumed_events, #{table_opts}) do
          add :consumer, :text, null: false, primary_key: true
          add :event_id, :text, null: false, primary_key: true
          add :inserted_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
        end
      end
    end
    """
  end

  @doc """
  Writes a migration to the given directory. The `timestamp_fun` allows
  tests to inject a deterministic timestamp.
  """
  @spec write_migration(Path.t(), String.t(), (-> String.t())) :: Path.t()
  def write_migration(dir, prefix, timestamp_fun) do
    timestamp = timestamp_fun.()
    filename = "#{timestamp}_create_outbox_events_table.exs"
    path = Path.join(dir, filename)

    module_name = "Outbox.Repo.Migrations.CreateOutboxEventsTable"
    body = render(prefix: prefix, module_name: module_name)

    File.write!(path, body)
    path
  end

  defp default_timestamp do
    {{y, m, d}, {h, mm, s}} = :calendar.universal_time()

    :io_lib.format("~4..0B~2..0B~2..0B~2..0B~2..0B~2..0B", [y, m, d, h, mm, s])
    |> IO.iodata_to_binary()
  end

  defp resolve_migrations_path(opts) do
    case Keyword.get(opts, :repo) do
      nil ->
        # Default to first :ecto_repos entry; fall back to a sensible default
        case Application.get_env(Mix.Project.config()[:app], :ecto_repos, []) do
          [repo | _] -> Path.join([File.cwd!(), "priv", priv_dir_for_repo(repo), "migrations"])
          [] -> Path.join([File.cwd!(), "priv", "repo", "migrations"])
        end

      repo_str ->
        repo = Module.concat([repo_str])
        Path.join([File.cwd!(), "priv", priv_dir_for_repo(repo), "migrations"])
    end
  end

  defp priv_dir_for_repo(repo) do
    repo
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end

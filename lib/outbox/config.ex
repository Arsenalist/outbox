defmodule Outbox.Config do
  @moduledoc """
  Read-only accessors for Outbox's application configuration.

  All reads go through `Application.get_env/2` at call time. No values
  are captured at compile time or process start, so config changes take
  effect immediately — important for tests that flip config between
  cases.

  All configuration lives in a single keyword list under
  `config :outbox, Outbox, [...]`.
  """

  @app :outbox

  defp opts, do: Application.get_env(@app, Outbox, [])

  @doc """
  Returns the host's configured Ecto Repo module.

  Raises a `RuntimeError` with a clear message if `repo:` is unset —
  silent `nil` would surface as a confusing `UndefinedFunctionError`
  deep inside `Ecto.Adapter.lookup_meta/1`.
  """
  @spec repo() :: module()
  def repo do
    case Keyword.get(opts(), :repo) do
      nil ->
        raise """
        Outbox is not configured with a Repo.

        Add to your `config/config.exs`:

            config :outbox, Outbox,
              repo: MyApp.Repo,
              subscribers: [...]
        """

      repo when is_atom(repo) ->
        repo
    end
  end

  @doc "Returns the list of registered subscriber modules. Defaults to `[]`."
  @spec subscribers() :: [module()]
  def subscribers, do: Keyword.get(opts(), :subscribers, [])

  @doc "Returns the prune retention window in days. Defaults to 30."
  @spec retention_days() :: pos_integer()
  def retention_days, do: Keyword.get(opts(), :retention_days, 30)

  @doc """
  Returns the Oban instance name to use for enqueueing subscriber jobs.

  Defaults to `Outbox.Oban` (the library's own instance, started by
  `Outbox.child_spec/1`). Hosts that want to share their existing Oban
  instance set `config :outbox, Outbox, oban: MyApp.Oban`.
  """
  @spec oban() :: module()
  def oban, do: Keyword.get(opts(), :oban, Outbox.Oban)

  @doc """
  Returns the Phoenix.PubSub server name to broadcast dispatched events
  on. Returns `nil` if not configured — in which case the dispatcher
  skips the broadcast step.
  """
  @spec pubsub() :: module() | nil
  def pubsub, do: Keyword.get(opts(), :pubsub)

  @doc "Returns the PubSub topic. Defaults to `\"domain_events\"`."
  @spec pubsub_topic() :: String.t()
  def pubsub_topic, do: Keyword.get(opts(), :pubsub_topic, "domain_events")
end

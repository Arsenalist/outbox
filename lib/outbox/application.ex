defmodule Outbox.Application do
  @moduledoc """
  Outbox's root supervisor.

  Started by adding `Outbox` to the host application's supervision tree:

      children = [
        MyApp.Repo,
        {Phoenix.PubSub, name: MyApp.PubSub},
        Outbox,
        MyAppWeb.Endpoint
      ]

  Brings up `Outbox.TaskSupervisor`, the library-owned Oban instance
  `Outbox.Oban` (queues + cron baked in), and the dispatcher `Outbox.Ticker`.

  When `config :outbox, oban: MyApp.Oban` is set, the library skips
  starting `Outbox.Oban` and reuses the host's instance — the host is
  responsible for declaring `outbox` and `outbox_prune` queues plus the
  `Outbox.Pruner` cron entry on that instance.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children = children(opts)
    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Computes the child spec list for the given opts. Exposed so tests can
  introspect the result without actually starting the tree.
  """
  @spec children(keyword()) :: list()
  def children(opts) do
    app_env = Application.get_env(:outbox, Outbox, [])
    host_oban = Keyword.get(opts, :oban) || Keyword.get(app_env, :oban)
    repo = Keyword.get(opts, :repo) || Keyword.get(app_env, :repo)

    base = [
      {Task.Supervisor, name: Outbox.TaskSupervisor}
    ]

    own_oban =
      if host_oban do
        []
      else
        unless repo do
          raise """
          Outbox cannot start its own Oban instance without a Repo.

          Add to your `config/config.exs`:

              config :outbox, Outbox,
                repo: MyApp.Repo,
                subscribers: [...]
          """
        end

        [
          {Oban,
           name: Outbox.Oban,
           repo: repo,
           testing: Keyword.get(app_env, :testing, :disabled),
           queues: [outbox: 10, outbox_prune: 1],
           plugins: [
             {Oban.Plugins.Cron, crontab: [{"0 3 * * *", Outbox.Pruner}]}
           ]}
        ]
      end

    ticker = [
      {Outbox.Ticker, Keyword.take(opts, [:enabled, :interval_ms])}
    ]

    base ++ own_oban ++ ticker
  end
end

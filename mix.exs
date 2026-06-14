defmodule Outbox.MixProject do
  use Mix.Project

  @version "0.1.0-beta.2"
  @source_url "https://github.com/Arsenalist/outbox"

  @moduledoc false

  # Outbox — transactional outbox + Oban fan-out + Phoenix.PubSub
  # broadcaster for Phoenix/Ecto/Oban apps. Host-agnostic by
  # construction: runtime deps locked to
  # `[:ecto_sql, :oban, :phoenix_pubsub, :jason]`, host injects its
  # Repo via `config :outbox, Outbox, repo: MyApp.Repo`, and
  # `test/outbox/architecture_test.exs` guards `lib/` against
  # host-app references. See README.md for install and usage.

  def project do
    [
      app: :outbox,
      version: @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Outbox",
      description: description(),
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:oban, "~> 2.18"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:postgrex, ">= 0.0.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Transactional outbox + Oban fan-out + Phoenix.PubSub broadcaster for Phoenix/Ecto apps. " <>
      "Minimal, opinionated, drop-in."
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Zarar Siddiqi"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md CONTRIBUTING.md CODE_OF_CONDUCT.md)
    ]
  end
end

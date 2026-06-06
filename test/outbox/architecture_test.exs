defmodule Outbox.ArchitectureTest do
  @moduledoc """
  Enforces the host-agnosticism boundary at compile/CI time.

  The Outbox library MUST NOT reference any host-app modules (Amplify,
  AmplifyWeb) and MUST keep its runtime dependency set narrow.

  No `@repo` module attributes are allowed either — Repo lookups must
  resolve at call time via `Outbox.Config.repo/0` (R-H4 compile-freeze
  guard).
  """

  use ExUnit.Case, async: true

  @lib_root Path.expand("../../lib", __DIR__)

  @forbidden_substrings [
    "Amplify.",
    "AmplifyWeb.",
    "amplify",
    "AmplifyWeb"
  ]

  @forbidden_module_attrs [
    "@repo "
  ]

  describe "lib/ files reference no host-app modules" do
    test "no `Amplify.` / `AmplifyWeb.` references in lib/" do
      offenders =
        @lib_root
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.flat_map(fn path ->
          content = File.read!(path)

          Enum.flat_map(@forbidden_substrings, fn token ->
            if String.contains?(content, token), do: [{path, token}], else: []
          end)
        end)

      assert offenders == [],
             "Outbox lib/ must not reference host-app modules. Offenders:\n" <>
               Enum.map_join(offenders, "\n", fn {path, token} ->
                 "  #{Path.relative_to(path, @lib_root)} — references #{inspect(token)}"
               end)
    end
  end

  describe "lib/ files do not freeze Repo via module attributes (R-H4)" do
    test "no `@repo ` definitions in lib/" do
      offenders =
        @lib_root
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.flat_map(fn path ->
          content = File.read!(path)

          Enum.flat_map(@forbidden_module_attrs, fn token ->
            if String.contains?(content, token), do: [{path, token}], else: []
          end)
        end)

      assert offenders == [],
             "Outbox lib/ must not capture Repo via @repo module attribute. Offenders:\n" <>
               Enum.map_join(offenders, "\n", fn {path, token} ->
                 "  #{Path.relative_to(path, @lib_root)} — uses #{inspect(token)}"
               end)
    end
  end

  describe "mix.exs runtime deps allowlist" do
    test "declares only ecto_sql, oban, phoenix_pubsub, jason as runtime deps" do
      deps = Outbox.MixProject.project()[:deps] || []

      runtime_deps =
        deps
        |> Enum.reject(&test_only_or_dev?/1)
        |> Enum.map(&elem(&1, 0))
        |> MapSet.new()

      allowed = MapSet.new([:ecto_sql, :oban, :phoenix_pubsub, :jason])

      assert runtime_deps == allowed,
             "runtime deps drift detected. expected: #{inspect(allowed)} got: #{inspect(runtime_deps)}"
    end

    defp test_only_or_dev?({_name, _ver, opts}) when is_list(opts) do
      only = Keyword.get(opts, :only)
      only in [:test, :dev, [:test], [:dev], [:test, :dev]]
    end

    defp test_only_or_dev?(_), do: false
  end
end

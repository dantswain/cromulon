defmodule Cromulon.Mixfile do
  use Mix.Project

  def project do
    [
      app: :cromulon,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      build_path: build_path(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Cromulon.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support", "test/cromulon_discovery"]
  defp elixirc_paths(_), do: ["lib"]

  defp build_path do
    System.get_env("CROMULON_BUILD_PATH") || "_build"
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.2"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:bolt_sips, "~> 0.4"},
      {:cowboy, "~> 1.0"},
      {:credo, "~> 0.9.2"},
      {:kafka_ex, "~> 0.8.2"},
      {:distillery, "~>1.5.2"},
      {:inflex, "~> 1.10.0"},
      {:snappy,
       git: "https://github.com/fdmanana/snappy-erlang-nif.git",
       ref: "0951a1bf8e58141b3c439bebe1f2992688298631"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end

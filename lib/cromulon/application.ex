defmodule Cromulon.Application do
  use Application

  require Logger

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      # supervisor(Cromulon.Repo, []),
      # Start the endpoint when the application starts
      supervisor(CromulonWeb.Endpoint, []),
      # Start your own worker by calling: Cromulon.Worker.start_link(arg1, arg2, arg3)
      # worker(Cromulon.Worker, [arg1, arg2, arg3]),
      worker(Bolt.Sips, [bolt_sips_config()])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cromulon.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def bolt_sips_config() do
    config = Application.get_env(:bolt_sips, Bolt)

    case System.get_env("NEO4J_URL") do
      nil ->
        config

      neo4j_url ->
        Logger.info(fn -> "Detected Neo4j URL: #{neo4j_url}" end)
        Keyword.put(config, :url, neo4j_url)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CromulonWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

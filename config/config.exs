# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :cromulon, ecto_repos: [Cromulon.Repo]

config :cromulon, Cromulon.Repo, priv: "priv/repo"

# Configures the endpoint
config :cromulon, CromulonWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "lrSinA9FNcAFAyqiDO1D7RsMVA2kBMyQ64m/VadkSY4kYMk+hfo2bKJYYmYt2HFJ",
  render_errors: [view: CromulonWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Cromulon.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# neo4j
config :bolt_sips, Bolt,
  hostname: 'localhost',
  port: 7687,
  pool_size: 10,
  max_overflow: 5

# kafka
config :kafka_ex,
  disable_default_worker: true,
  use_ssl: false,
  consumer_group: :no_consumer_group

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

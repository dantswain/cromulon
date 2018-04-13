use Mix.Config

config :cromulon,
  ecto_repos: [Cromulon.Repo, CromulonDiscoveryTest.Repo]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cromulon, CromulonWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :cromulon, Cromulon.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "cromulon_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Configure your database
config :cromulon, CromulonDiscoveryTest.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "cromulon_discovery_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

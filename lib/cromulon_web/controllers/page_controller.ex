defmodule CromulonWeb.PageController do
  use CromulonWeb, :controller

  require Logger

  alias Bolt.Sips
  alias Cromulon.Discovery.Postgres
  alias Cromulon.Discovery.Postgres.Database

  alias Cromulon.Schema

  def index(conn, _params) do
    redirect(conn, to: source_path(conn, :index))
  end
end

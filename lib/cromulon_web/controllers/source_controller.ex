defmodule CromulonWeb.SourceController do
  use CromulonWeb, :controller

  require Logger

  alias Bolt.Sips

  alias Cromulon.Discovery.Postgres, as: PGDiscovery
  alias Cromulon.Schema

  def index(conn, _params) do
    bolt = Sips.conn()

    sources = Schema.list_sources(bolt)

    render(conn, "index.html", %{sources: sources})
  end

  def show(conn, %{"source_uuid" => source_uuid}) do
    bolt = Sips.conn()

    result = Schema.list_source_nodes(source_uuid, bolt)

    render(conn, "show.html", %{source: result.source, nodes: result.nodes})
  end

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"source" => source}) do
    bolt = Sips.conn()
    schema = PGDiscovery.describe_database(source["connection_string"])
    Schema.ingest(schema, bolt)

    redirect(conn, to: source_path(conn, :index))
  end
end

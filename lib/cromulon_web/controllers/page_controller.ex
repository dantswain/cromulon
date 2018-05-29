defmodule CromulonWeb.PageController do
  use CromulonWeb, :controller

  require Logger

  alias Bolt.Sips
  alias Cromulon.Discovery.Postgres
  alias Cromulon.Discovery.Postgres.Database

  alias Cromulon.Schema

  def index(conn, _params) do
    bolt = Sips.conn()

    sources = Schema.list_sources(bolt)

    render(conn, "index.html", %{sources: sources})
  end

  def source(conn, %{"source_uuid" => source_uuid}) do
    bolt = Sips.conn()

    result = Schema.list_source_nodes(source_uuid, bolt)

    render(conn, "source.html", %{source: result.source, nodes: result.nodes})
  end

  def node(conn, %{"node_uuid" => node_uuid}) do
    bolt = Sips.conn()

    result = Schema.describe_node(node_uuid, bolt)

    render(conn, "node.html", %{source: result.source, node: result.node,
      inbound: result.inbound, outbound: result.outbound})
  end

  # HACK should use a real resource controller
  def new_database(conn, %{"data_source" => data_source}) do
    uri = data_source["uri"]

    spawn(fn ->
      uri
      |> Database.from_url()
      |> Postgres.crawl_database()
      |> Postgres.merge_database_to_graph()
    end)

    conn
    |> put_flash(:info, "The database at #{uri} is being crawled and should show up soon")
    |> redirect(to: page_path(conn, :index))
  end
end

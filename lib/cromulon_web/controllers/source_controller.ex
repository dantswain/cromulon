defmodule CromulonWeb.SourceController do
  use CromulonWeb, :controller

  require Logger

  alias Bolt.Sips

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
end

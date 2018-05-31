defmodule CromulonWeb.NodeController do
  use CromulonWeb, :controller

  require Logger

  alias Bolt.Sips

  alias Cromulon.Schema

  def show(conn, %{"node_uuid" => node_uuid}) do
    bolt = Sips.conn()

    result = Schema.describe_node(node_uuid, bolt)

    render(conn, "show.html", %{source: result.source, node: result.node,
      inbound: result.inbound, outbound: result.outbound})
  end
end

defmodule CromulonWeb.NodeController do
  use CromulonWeb, :controller

  require Logger

  alias Bolt.Sips

  alias Cromulon.Schema
  alias Cromulon.Schema.Source
  alias Cromulon.Schema.Node

  def show(conn, %{"node_uuid" => node_uuid}) do
    bolt = Sips.conn()

    result = Schema.describe_node(node_uuid, bolt)

    inbound_by_label = Enum.group_by(result.inbound, &by_label/1)
    outbound_by_label = Enum.group_by(result.outbound, &by_label/1)

    render(conn, "show.html", %{
      source: result.source,
      node: result.node,
      inbound_by_label: inbound_by_label,
      outbound_by_label: outbound_by_label
    })
  end

  defp by_label(%{edge: e}), do: e.label
end

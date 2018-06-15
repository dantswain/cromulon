defmodule CromulonWeb.SampleController do
  use CromulonWeb, :controller

  alias Bolt.Sips

  alias Cromulon.Schema

  def show(conn, %{"node_uuid" => node_uuid}) do
    bolt = Sips.conn()
    node = Schema.get_node(node_uuid, bolt)

    messages = Enum.map(node.attributes["sample_messages"], &Poison.decode!/1)

    conn
    |> put_status(:ok)
    |> json(messages)
  end
end

defmodule CromulonWeb.SampleController do
  use CromulonWeb, :controller

  alias Bolt.Sips

  alias Cromulon.Schema

  def show(conn, %{"node_uuid" => node_uuid}) do
    bolt = Sips.conn()
    node = Schema.get_node(node_uuid, bolt)

    if json_messages?(node) do
      messages = Enum.map(node.attributes["sample_messages"], &Poison.decode!/1)

      conn
      |> put_status(:ok)
      |> json(messages)
    else
      conn
      |> put_status(:ok)
      |> text(Enum.join(node.attributes["sample_messages"], "\n"))
    end
  end

  defp json_messages?(node) do
    case node.attributes["sample_messages"] do
      [h | _] when is_binary(h) ->
        case Poison.decode(h) do
          {:ok, _} -> true
          _ -> false
        end
      _ ->
        false
    end
  end
end

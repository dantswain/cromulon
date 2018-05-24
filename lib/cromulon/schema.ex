defmodule Cromulon.Schema do
  @moduledoc false

  alias Ecto.UUID

  alias Bolt.Sips, as: Bolt

  alias Cromulon.Schema.Edge
  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Source

  def ensure_uuid(m = %{uuid: nil}), do: %{m | uuid: UUID.generate()}
  def ensure_uuid(m), do: m

  def select_nodes(list) when is_list(list) do
    Enum.filter(list, fn
      %Node{} -> true
      _ -> false
    end)
  end

  def select_edges(list) when is_list(list) do
    Enum.filter(list, fn
      %Edge{} -> true
      _ -> false
    end)
  end

  def find_by_uuid(list, uuid) when is_list(list) and is_binary(uuid) do
    Enum.find(list, fn el -> Map.get(el, :uuid) == uuid end)
  end

  def ingest(schema, bolt_conn) when is_list(schema) do
    schema
    |> Enum.sort_by(&ingest_sort_order/1)
    |> Enum.flat_map(&ingest_element(&1, bolt_conn))
  end

  # The order in which we need to ingest elements in the graph
  #   lower number is earlier (e.g., edges probably need to go last)
  defp ingest_sort_order(%Source{}), do: 1
  defp ingest_sort_order(%Node{}), do: 2
  defp ingest_sort_order(%Edge{}), do: 3

  defp ingest_element(source = %Source{}, bolt_conn) do
    cypher = """
    MERGE (n:Source { uuid: $uuid })
    SET n = $props
    RETURN n
    """

    Bolt.query!(bolt_conn, cypher, %{"props" => props(source), "uuid" => source.uuid})
  end

  defp ingest_element(node = %Node{}, bolt_conn) do
    cypher = """
    MERGE (n:Node { uuid: $uuid })
    SET n = $props
    RETURN n
    """

    Bolt.query!(bolt_conn, cypher, %{"props" => props(node), "uuid" => node.uuid})
  end

  defp ingest_element(edge = %Edge{}, bolt_conn) do
    cypher = """
    MATCH (f { uuid: $from_uuid }), (t { uuid: $to_uuid })
    MERGE (t)<-[r:#{edge.label} { uuid: $uuid, attributes: $attributes }]-(f)
    RETURN r
    """

    Bolt.query!(bolt_conn, cypher, %{
      "from_uuid" => edge.from_uuid,
      "to_uuid" => edge.to_uuid,
      "uuid" => edge.uuid,
      "attributes" => Poison.encode!(edge.attributes)
    })
  end

  defp props(source = %{__struct__: m}) when m in [Node, Source] do
    source
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> Map.put(:attributes, Poison.encode!(source.attributes))
  end
end

defmodule CromulonWeb.NodeView do
  use CromulonWeb, :view

  import CromulonWeb.SchemaView

  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Source

  @outbound_mapping %{
    "TABLE" => "schema",
    "COLUMN" => "table",
    "FOREIGN_KEY" => "foreign table",
    "MESSAGE" => "parent message",
    "TOPIC_MESSAGE_FIELD" => "topic"
  }

  def node_info(node = %Node{}, source = %Source{}, conn) do
    common_node_info(node, source, conn) ++ specific_node_info(node, source, conn)
  end

  def describe_node_kind(%Node{kind: kind}), do: titleize(kind)

  def child_node_info(node = %Node{}) do
    node.types
    |> List.wrap()
    |> Enum.map(&String.downcase/1)
    |> Enum.join(", ")
  end

  def describe_inbound_relationships(name, len) do
    name
    |> titleize
    |> Inflex.inflect(len)
  end

  def describe_outbound_relationships(name, len) do
    @outbound_mapping
    |> Map.get(name, name)
    |> titleize
    |> Inflex.inflect(len)
  end

  def show_sample_messages(node = %Node{kind: "kafka topic"}) do
    case Map.get(node.attributes, "sample_messages") do
      nil ->
        "None available"

      messages ->
        for message <- messages do
          case Poison.decode(message) do
            {:ok, decoded} ->
              raw("<pre>" <> Poison.encode!(decoded, pretty: true) <> "</pre>")
            {:error, _} ->
              raw("<pre>" <> message <> "</pre>")
          end
        end
    end
  end

  def show_sample_messages?(node = %Node{}) do
    node.kind == "kafka topic" && !Enum.empty?(Map.get(node.attributes, "sample_messages"))
  end

  def sample_messages_link(node = %Node{kind: "kafka topic"}, conn) do
    case Map.get(node.attributes, "sample_messages") do
      nil ->
        nil

      _messages ->
        link("Download", to: sample_path(conn, :show, node.uuid))
    end
  end

  defp titleize(name) do
    name
    |> String.split(["_", " "])
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp common_node_info(_node, source, conn) do
    [
      {"Source", link(source.name, to: source_path(conn, :show, source.uuid))}
    ]
  end

  defp specific_node_info(node = %Node{kind: "column"}, _, _) do
    [
      {"Data Types", node.types}
    ]
  end

  defp specific_node_info(node = %Node{kind: "message"}, _, _) do
    [
      {"Data Types", node.types}
    ]
  end

  defp specific_node_info(node = %Node{kind: "kafka topic"}, _, _) do
    partition_ids = node.attributes["partition_ids"]

    [
      {"Partition Count", Integer.to_string(length(partition_ids))}
    ]
  end

  defp specific_node_info(_, _, _), do: []
end

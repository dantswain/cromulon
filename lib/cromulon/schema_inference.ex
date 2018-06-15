defmodule Cromulon.SchemaInference do
  require Logger

  alias Ecto.UUID
  alias Cromulon.Schema
  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Edge

  def from_sample_messages(messages, parent_node \\ nil, parent_edge_label \\ "MESSAGE") do
    messages = try_json(messages)

    infer_schema(messages, parent_node, parent_edge_label)
  rescue
    e ->
      Logger.warn(fn ->
        if parent_node do
          "Unable to infer schema for #{parent_node.name}: #{inspect(e)}"
        else
          "Unable to infer schema: #{inspect(e)}"
        end
      end)

      []
  end

  def infer_schema(messages, parent_node \\ nil, parent_edge_label \\ "MESSAGE") do
    field_names =
      messages
      |> Enum.map(&Map.keys/1)
      |> List.flatten()
      |> Enum.uniq()

    collected =
      Enum.reduce(messages, %{}, fn m, acc ->
        Enum.reduce(field_names, acc, fn f, acc1 ->
          value = Map.get(m, f)
          Map.update(acc1, f, [value], fn ex -> [value | ex] end)
        end)
      end)

    Enum.map(field_names, fn field_name ->
      values = Map.get(collected, field_name)
      type = detect_type(values)
      node = %Node{uuid: UUID.generate(), name: field_name, kind: "message field"}

      case type do
        [{:list, [:map]}] ->
          flat_values = List.flatten(values)
          message_schema = infer_schema(flat_values, node)

          if parent_node do
            edge = %Edge{
              from_uuid: node.uuid,
              to_uuid: parent_node.uuid,
              label: parent_edge_label,
              uuid: UUID.generate()
            }

            [%{node | types: "List of message"}, edge, message_schema]
          else
            [%{node | types: "message"}, message_schema]
          end

        [:map] ->
          message_schema = infer_schema(values, node)

          if parent_node do
            edge = %Edge{
              from_uuid: node.uuid,
              to_uuid: parent_node.uuid,
              label: parent_edge_label,
              uuid: UUID.generate()
            }

            [%{node | types: "message"}, edge, message_schema]
          else
            [%{node | types: "message"}, message_schema]
          end

        type ->
          if parent_node do
            edge = %Edge{
              from_uuid: node.uuid,
              to_uuid: parent_node.uuid,
              label: parent_edge_label,
              uuid: UUID.generate()
            }

            [%{node | types: type_label(type)}, edge]
          else
            %{node | types: type_label(type)}
          end
      end
    end)
  end

  defp try_json(messages) do
    Enum.map(messages, &Poison.decode!/1)
  end

  defp type_label({:list, x}), do: "List of " <> Enum.join(type_label(x), ",")
  defp type_label(x) when is_list(x), do: Enum.map(x, &type_label/1)
  defp type_label(x), do: Atom.to_string(x)

  def detect_type(values) when is_list(values) do
    values
    |> Enum.map(&type_of/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def type_of(x) when is_integer(x), do: :integer
  def type_of(x) when is_float(x), do: :float
  def type_of(x) when is_binary(x), do: :string
  def type_of(x) when is_boolean(x), do: :boolean
  def type_of(x) when is_list(x), do: {:list, detect_type(x)}
  def type_of(nil), do: :null
  def type_of(x) when is_map(x), do: :map
  def type_of(_), do: :unknown
end

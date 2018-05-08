defmodule Cromulon.SchemaInference do
  def from_sample_messages(messages) do
    messages = try_json(messages)

    infer_schema(messages)
  end

  def try_json(messages) do
    Enum.map(messages, &Poison.decode!/1)
  end

  def infer_schema(messages) do
    field_names = messages
                  |> Enum.map(&Map.keys/1)
                  |> List.flatten
                  |> Enum.uniq

    collected = Enum.reduce(messages, %{}, fn(m, acc) ->
      Enum.reduce(field_names, acc, fn(f, acc1) ->
        value = Map.get(m, f)
        Map.update(acc1, f, [value], fn(ex) -> [value | ex] end)
      end)
    end)

    field_names
    |> Enum.map(fn(f) ->
      values = Map.get(collected, f)
      type = detect_type(values)
      case type do
        [{:list, [:map]}] ->
          flat_values = List.flatten(values)
          {f, {:list, {:map, [infer_schema(flat_values)]}}}
        [:map] -> {f, {:map, [infer_schema(values)]}}
        type -> {f, type}
      end
    end)
    |> Enum.into(%{})
  end

  def detect_type(values) when is_list(values) do
    values
    |> Enum.map(&type_of/1)
    |> Enum.uniq
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

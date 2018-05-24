defmodule Cromulon.Schema do
  @moduledoc false

  def ensure_uuid(m = %{uuid: nil}), do: %{m | uuid: Ecto.UUID.generate()}
  def ensure_uuid(m), do: m

  defmodule Source do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "sources" do
      field(:name, :string)
      field(:connection_info, :string)
      field(:kind, :string)
      field(:attributes, :map, default: %{})
      field(:uuid, :string)
    end
  end

  defmodule Node do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "columns" do
      field(:name, :string)
      field(:kind, :string)
      field(:types, :string)
      field(:attributes, :map, default: %{})
      field(:uuid, :string)
    end

    def kind?(%Node{kind: kind}, kind), do: true
    def kind?(_, _), do: false
  end

  defmodule Edge do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "edges" do
      field(:from_uuid, :string)
      field(:to_uuid, :string)
      field(:uuid, :string)
      field(:label, :string)
      field(:attributes, :map, default: %{})
    end
  end

  alias Cromulon.Schema.Node

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
end

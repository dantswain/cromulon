defmodule Cromulon.Schema.Node do
  @moduledoc false
  use Ecto.Schema

  alias Bolt.Sips.Types.Node, as: BoltNode

  @primary_key false
  schema "columns" do
    field(:name, :string)
    field(:kind, :string)
    field(:types, :string)
    field(:attributes, :map, default: %{})
    field(:uuid, :string)
  end

  def kind?(%__MODULE__{kind: kind}, kind), do: true
  def kind?(_, _), do: false

  def from_bolt(node = %BoltNode{}) do
    %__MODULE__{
      name: node.properties["name"],
      kind: node.properties["kind"],
      types: node.properties["types"],
      attributes: Poison.decode!(node.properties["attributes"]),
      uuid: node.properties["uuid"]
    }
  end
end

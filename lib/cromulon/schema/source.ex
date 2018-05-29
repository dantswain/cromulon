defmodule Cromulon.Schema.Source do
  @moduledoc false
  use Ecto.Schema

  alias Bolt.Sips.Types.Node, as: BoltNode

  @primary_key false
  schema "sources" do
    field(:name, :string)
    field(:connection_info, :string)
    field(:kind, :string)
    field(:attributes, :map, default: %{})
    field(:uuid, :string)
  end

  def from_bolt(node = %BoltNode{}) do
    %__MODULE__{
      name: node.properties["name"],
      connection_info: node.properties["connection_info"],
      kind: node.properties["kind"],
      attributes: Poison.decode!(node.properties["attributes"]),
      uuid: node.properties["uuid"]
    }
  end
end

defmodule Cromulon.Schema.Edge do
  @moduledoc false
  use Ecto.Schema

  alias Bolt.Sips.Types.Relationship

  @primary_key false
  schema "edges" do
    field(:from_uuid, :string)
    field(:to_uuid, :string)
    field(:uuid, :string)
    field(:label, :string)
    field(:attributes, :map, default: %{})
  end

  def from_bolt(relation = %Relationship{}) do
    %__MODULE__{
      label: relation.type,
      attributes: Poison.decode!(relation.properties["attributes"]),
      uuid: relation.properties["uuid"]
    }
  end
end

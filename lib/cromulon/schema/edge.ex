defmodule Cromulon.Schema.Edge do
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

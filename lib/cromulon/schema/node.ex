defmodule Cromulon.Schema.Node do
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

  def kind?(%__MODULE__{kind: kind}, kind), do: true
  def kind?(_, _), do: false
end

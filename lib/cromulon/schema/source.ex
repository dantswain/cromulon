defmodule Cromulon.Schema.Source do
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

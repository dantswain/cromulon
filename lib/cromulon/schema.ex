defmodule Cromulon.Schema do
  @moduledoc false

  def ensure_uuid(m = %{uuid: nil}), do: %{m | uuid: Ecto.UUID.generate()}
  def ensure_uuid(m), do: m

  defmodule Source do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "sources" do
      field :name, :string
      field :connection_info, :string
      field :kind, :string
      field :attributes, :map
      field :uuid, :string
      embeds_many :nodes, {:list, __MODULE__}
    end
  end

  defmodule Node do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "columns" do
      field :name, :string
      field :kind, :string
      field :types, :string
      field :attributes, :map
      field :uuid, :string
    end
  end

  defmodule Edge do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "edges" do
      field :from_uuid, :string
      field :to_uuid, :string
      field :uuid, :string
      field :label, :string
      field :attributes, :map
    end
  end
end

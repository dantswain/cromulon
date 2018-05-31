defmodule CromulonWeb.SourceView do
  use CromulonWeb, :view

  import CromulonWeb.SchemaView

  alias Cromulon.Schema.Source

  def group_sources(sources) when is_list(sources) do
    Enum.reduce(sources, %{}, fn(source, acc) ->
      Map.update(acc, source.kind, [source], fn(x) -> [source | x] end)
    end)
  end

  def describe_source_kind_plural("postgres database"), do: "Postgres Databases"
  def describe_source_kind_plural(other), do: other

  def describe_source_kind(%Source{kind: "postgres database"}), do: "Postgres Database"
  def describe_source_kind(other), do: other.kind

  def describe_source_nodes(%Source{kind: "postgres database"}), do: "Schemas"
end

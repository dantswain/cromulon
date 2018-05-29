defmodule CromulonWeb.PageView do
  use CromulonWeb, :view

  alias Cromulon.Schema.Edge
  alias Cromulon.Schema.Node
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

  def describe_node_kind(%Node{kind: "postgres schema"}), do: "Postgres Schema"
  def describe_node_kind(%Node{kind: "table"}), do: "Table"
  def describe_node_kind(%Node{kind: "column"}), do: "Column"

  def describe_inbound_relationship(%Edge{label: "TABLE"}), do: "Table"
  def describe_inbound_relationship(%Edge{label: "COLUMN"}), do: "Column"
  def describe_inbound_relationship(%Edge{label: "FOREIGN_KEY"}), do: "Foreign Key"

  def describe_outbound_relationship(%Edge{label: "TABLE"}), do: "Schema"
  def describe_outbound_relationship(%Edge{label: "COLUMN"}), do: "Table"
  def describe_outbound_relationship(%Edge{label: "FOREIGN_KEY"}), do: "Foreign Table"

  def source_link(source) do
    link(source.name, to: "/sources/#{source.uuid}")
  end

  def node_link(node) do
    link(node.name, to: "/nodes/#{node.uuid}")
  end
end

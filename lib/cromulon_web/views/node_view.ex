defmodule CromulonWeb.NodeView do
  use CromulonWeb, :view

  import CromulonWeb.SchemaView

  alias Cromulon.Schema.Edge
  alias Cromulon.Schema.Node

  def describe_node_kind(%Node{kind: "postgres schema"}), do: "Postgres Schema"
  def describe_node_kind(%Node{kind: "table"}), do: "Table"
  def describe_node_kind(%Node{kind: "column"}), do: "Column"
  def describe_node_kind(%Node{kind: "kafka topic"}), do: "Kafka Topic"
  def describe_node_kind(%Node{kind: "message"}), do: "Message"

  def describe_inbound_relationship(%Edge{label: "TABLE"}), do: "Table"
  def describe_inbound_relationship(%Edge{label: "COLUMN"}), do: "Column"
  def describe_inbound_relationship(%Edge{label: "FOREIGN_KEY"}), do: "Foreign Key"
  def describe_inbound_relationship(%Edge{label: "MESSAGE"}), do: "Message"

  def describe_outbound_relationship(%Edge{label: "TABLE"}), do: "Schema"
  def describe_outbound_relationship(%Edge{label: "COLUMN"}), do: "Table"
  def describe_outbound_relationship(%Edge{label: "FOREIGN_KEY"}), do: "Foreign Table"
  def describe_outbound_relationship(%Edge{label: "MESSAGE"}), do: "Parent Message"
end

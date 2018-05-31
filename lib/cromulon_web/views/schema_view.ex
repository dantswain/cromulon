defmodule CromulonWeb.SchemaView do
  @moduledoc """
  View helpers that are shared across views that show schema elements
  """

  use Phoenix.HTML

  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Source

  import CromulonWeb.Router.Helpers

  def node_link(node = %Node{}, conn) do
    link(node.name, to: node_path(conn, :show, node.uuid))
  end

  def source_link(source = %Source{}, conn) do
    link(source.name, to: source_path(conn, :show, source.uuid))
  end
end

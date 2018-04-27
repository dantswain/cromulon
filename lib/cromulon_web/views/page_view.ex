defmodule CromulonWeb.PageView do
  use CromulonWeb, :view

  alias Bolt.Sips.Types.Node

  def database_path(%Node{id: id}) do
    "/database/#{id}"
  end

  def table_path(%Node{id: table_id}) do
    "/table/#{table_id}"
  end
end

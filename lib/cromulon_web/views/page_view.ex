defmodule CromulonWeb.PageView do
  use CromulonWeb, :view

  def table_link(table_name) when is_binary(table_name) do
    "/table?name=#{table_name}"
  end
end

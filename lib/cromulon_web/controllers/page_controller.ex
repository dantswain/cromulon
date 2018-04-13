defmodule CromulonWeb.PageController do
  use CromulonWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end

defmodule CromulonWeb.PageControllerTest do
  use CromulonWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 302) =~ "/sources"
  end
end

defmodule CromulonWeb.PageController do
  use CromulonWeb, :controller

  alias Bolt.Sips

  def index(conn, _params) do
    bolt = Sips.conn()
    databases = bolt
                |> Sips.query!("MATCH (d: Database) RETURN (d)")
                |> Enum.map(fn(%{"d" => d}) -> d end)
    render conn, "index.html", %{databases: databases}
  end

  # HACK should use a real resource controller
  def database(conn, %{"name" => database_name}) do
    bolt = Sips.conn()
    tables = bolt
             |> Sips.query!(
               "MATCH (d:Database {name: $database_name}) -[:has_table]-> (t:Table) RETURN (t)",
               %{database_name: database_name}
             )
             |> Enum.map(fn(%{"t" => t}) -> t end)
    render conn, "database.html", %{tables: tables, database_name: database_name}
  end

  def table(conn, %{"name" => table_name}) do
    bolt = Sips.conn()
    tables = bolt
             |> Sips.query!(
               "MATCH (t:Table {name: $table_name}) -[:has_column]-> (c:Column) RETURN (c)",
               %{table_name: table_name}
             )
             |> Enum.map(fn(%{"c" => c}) -> c end)
    render conn, "table.html", %{columns: tables, table_name: table_name}
  end

end

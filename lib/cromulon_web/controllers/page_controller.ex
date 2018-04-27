defmodule CromulonWeb.PageController do
  use CromulonWeb, :controller

  require Logger

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
    columns = bolt
              |> Sips.query!(
                "MATCH (t:Table {name: $table_name}) -[:has_column]-> (c:Column) RETURN (c)",
                %{table_name: table_name}
              )
              |> Enum.map(fn(%{"c" => c}) -> c end)

    fk_out_cypher = """
    MATCH (t:Table {name: $table_name}) -[:has_column]-> (c:Column) -[:foreign_key]-> (ot:Table)
    RETURN c, ot
    """
    fks_outbound = bolt
                   |> Sips.query!(fk_out_cypher, %{table_name: table_name})
                   |> Enum.map(fn(%{"c" => c, "ot" => ot}) ->
                     {c.properties["name"], ot.properties["name"]}
                   end)
                   |> Enum.into(%{})

    Logger.debug(fn -> "OUTBOUND: #{inspect fks_outbound}" end)

    fk_in_cypher = """
    MATCH (t:Table {name: $table_name}) <-[:foreign_key]- (c:Column)
    RETURN c
    """
    fks_inbound = bolt
                  |> Sips.query!(fk_in_cypher, %{table_name: table_name})
                  |> Enum.map(fn(%{"c" => c}) -> c end)
    Logger.debug(fn -> "INBOUND #{inspect fks_inbound}" end)

    render(
      conn,
      "table.html",
      %{
        columns: columns,
        table_name: table_name,
        fks_outbound: fks_outbound,
        fks_inbound: fks_inbound
      }
    )
  end

end

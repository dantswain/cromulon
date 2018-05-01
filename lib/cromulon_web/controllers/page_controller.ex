defmodule CromulonWeb.PageController do
  use CromulonWeb, :controller

  require Logger

  alias Bolt.Sips
  alias Cromulon.Discovery.Postgres
  alias Cromulon.Discovery.Postgres.Database

  def index(conn, _params) do
    bolt = Sips.conn()
    databases = bolt
                |> Sips.query!("MATCH (d: Database) RETURN (d)")
                |> Enum.map(fn(%{"d" => d}) -> d end)
    render conn, "index.html", %{databases: databases}
  end

  # HACK should use a real resource controller
  def new_database(conn, %{"data_source" => data_source}) do
    uri = data_source["uri"]

    spawn(fn ->
      uri
      |> Database.from_url
      |> Postgres.crawl_database
      |> Postgres.merge_database_to_graph
    end)

    conn
    |> put_flash(:info, "The database at #{uri} is being crawled and should show up soon")
    |> redirect to: page_path(conn, :index)
  end

  def database(conn, %{"database_id" => database_id}) do
    bolt = Sips.conn()

    cypher = """
    MATCH (d:Database) -[:has_table]-> (t:Table)
    WHERE ID(d) = $database_id RETURN d, collect(t) AS ts
    """

    [result] = Sips.query!(bolt, cypher, %{database_id: String.to_integer(database_id)})
    tables = result["ts"]
    database = result["d"]

    render conn, "database.html", %{tables: tables, database: database}
  end

  def table(conn, %{"table_id" => table_id}) do
    table_id = String.to_integer(table_id)
    bolt = Sips.conn()

    cypher = """
    MATCH (d) -[:has_table]-> (t) -[:has_column]-> (c)
    WHERE ID(t) = $table_id
    RETURN d, t, collect(c) AS cs
    """
    [result] = Sips.query!(bolt, cypher, %{table_id: table_id})
    database = result["d"]
    table = result["t"]
    columns = result["cs"]

    fk_out_cypher = """
    MATCH (t) -[:has_column]-> (c) -[:foreign_key]-> (ft:Table)
    WHERE ID(t) = $table_id
    RETURN c.name AS column_name, ft AS foreign_table
    """
    fks_outbound = bolt
                   |> Sips.query!(fk_out_cypher, %{table_id: table_id})
                   |> Enum.map(
                     fn(%{"column_name" => column_name, "foreign_table" => foreign_table}) ->
                         {column_name, foreign_table}
                     end)
                   |> Enum.into(%{})

    fk_in_cypher = """
    MATCH (t) <-[:foreign_key]- (c) <-[:has_column]- (ft)
    WHERE ID(t) = $table_id
    RETURN c.name AS column_name, ft AS foreign_table
    """
    fks_inbound = Sips.query!(bolt, fk_in_cypher, %{table_id: table_id})

    Logger.debug(fn -> "INBOUND #{inspect fks_inbound}" end)

    render(
      conn,
      "table.html",
      %{
        database: database,
        columns: columns,
        table: table,
        fks_outbound: fks_outbound,
        fks_inbound: fks_inbound
      }
    )
  end
end

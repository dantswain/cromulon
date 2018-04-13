defmodule Cromulon.Discovery.Postgres do
  defmodule Column do
    use Ecto.Schema

    @primary_key false
    schema "columns" do
      field :column_name, :string
      field :column_default, :string
      field :is_nullable, :string
      field :data_type, :string
    end
  end

  alias Bolt.Sips, as: Bolt
  alias Cromulon.Repo
  alias Cromulon.Discovery.Postgres.Column

  def crawl_database(url) do
    insert_database_into_graph(url)

    for table <- list_tables(url) do
      columns = describe_table(url, table)
      insert_table_into_graph(url, table, columns)
    end
  end

  def insert_database_into_graph(url) do
    parsed_url = URI.parse(url)
    "/" <> database = parsed_url.path

    conn = Bolt.conn()
    cypher = """
    MERGE (d:Database { name: $database, url: $url })
    """
    Bolt.query(conn, cypher, %{database: database, url: url})
  end

  def insert_table_into_graph(url, table, columns) do
    parsed_url = URI.parse(url)
    "/" <> database = parsed_url.path

    conn = Bolt.conn()
    cypher = """
    MATCH (d:Database { name: $database, url: $url })
    MERGE (t:Table { name: $table })-[:has_table]->(d)
    """
    Bolt.query(conn, cypher, %{table: table, database: database, url: url})

    for column <- columns do
      params = %{
        table: table,
        database: database,
        column_name: column.column_name,
        data_type: column.data_type
      }

      cypher = """
      MERGE (c:Column { name: $column_name, data_type: $data_type })
      """
      Bolt.query(conn, cypher, params)

      cypher = """
      MATCH (t:Table { name: $table })
      MATCH (c:Column {name: $column_name, data_type: $data_type })
      MERGE (t)-[:has_column]->(c)
      """
      Bolt.query(conn, cypher, params)
    end
  end

  def list_databases(url) do
    url
    |> rows!("SELECT datname FROM pg_database WHERE datistemplate = 'f'")
    |> List.flatten
  end

  def list_tables(url) do
    query = "SELECT table_name FROM information_schema.tables WHERE " <>
      "table_schema = 'public'"

    url
    |> rows!(query)
    |> List.flatten
  end

  def describe_table(url, table) do
    query = "SELECT * from information_schema.columns WHERE table_name = $1"

    results = query!(url, query, [table])
    Enum.map(results.rows, &Repo.load(Column, {results.columns, &1}))
  end

  defp with_connection(url, cb) do
    params = Ecto.Repo.Supervisor.parse_url(url)
    {:ok, pid} = Postgrex.start_link(params)

    result = cb.(pid)

    Process.unlink(pid)
    GenServer.stop(pid)

    result
  end

  defp query!(url, query, params \\ []) do
    with_connection(
      url,
      fn(pid) -> Postgrex.query!(pid, query, params) end
    )
  end

  defp rows!(url, query, params \\ []) do
    url
    |> query!(query, params)
    |> Map.get(:rows)
  end
end

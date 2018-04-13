defmodule Cromulon.Discovery.Postgres do
  defmodule Column do
    use Ecto.Schema

    @primary_key false
    schema "columns" do
      field :name, :string
      field :data_type, :string
    end
  end

  defmodule Table do
    use Ecto.Schema

    @primary_key false
    schema "tables" do
      field :name, :string
      embeds_many :columns, Cromulon.Discovery.Postgres.Column
    end

    def tables_by_name(tables) do
      tables
      |> Enum.map(&({&1.name, &1}))
      |> Enum.into(%{})
    end
  end

  defmodule Database do
    use Ecto.Schema

    @primary_key false
    schema "databases" do
      field :url, :string
      field :name, :string
      embeds_many :tables, Cromulon.Discovery.Postgres.Table
    end

    def from_url(url) do
      parsed_url = URI.parse(url)
      "/" <> name = parsed_url.path

      %Database{url: url, name: name}
    end

    def relocate(database, url) do
      parsed_url = URI.parse(url)
      parsed_url = %{parsed_url | path: "/#{database.name}"}
      %{database | url: URI.to_string(parsed_url)}
    end
  end

  alias Bolt.Sips, as: Bolt
  alias Cromulon.Repo
  alias Cromulon.Discovery.Postgres.Column
  alias Cromulon.Discovery.Postgres.Table
 
  def crawl_database(db = %Database{}) do
    tables = Enum.map(
      list_tables(db),
      fn(table) ->
        %{table | columns: describe_columns(db, table)}
      end
    )
    %{db | tables: tables}
  end

  def merge_database_to_graph(db = %Database{}) do
    conn = Bolt.conn()
    cypher = """
    MERGE (d:Database { name: $name, url: $url })
    """
    Bolt.query!(conn, cypher, %{name: db.name, url: db.url})

    for table <- db.tables do
      merge_table_to_graph(table, db)
    end
  end

  def merge_table_to_graph(table, db) do
    conn = Bolt.conn()
    cypher = """
    MATCH (d:Database { name: $database, url: $url })
    MERGE (t:Table { name: $table })<-[:has_table]-(d)
    """
    Bolt.query!(
      conn,
      cypher,
      %{table: table.name, database: db.name, url: db.url}
    )

    for column <- table.columns do
      params = %{
        table: table.name,
        database: db.name,
        column_name: column.name,
        data_type: column.data_type
      }

      cypher = """
      MERGE (c:Column { name: $column_name, data_type: $data_type })
      """
      Bolt.query!(conn, cypher, params)

      cypher = """
      MATCH (t:Table { name: $table })
      MATCH (c:Column {name: $column_name, data_type: $data_type })
      MERGE (t)-[:has_column]->(c)
      """
      Bolt.query!(conn, cypher, params)
    end
  end

  def list_databases(url) do
    query = "SELECT datname AS name FROM pg_database WHERE datistemplate = 'f'"

    results = query!(url, query, [])
    results.rows
    |> Enum.map(&Repo.load(Database, {results.columns, &1}))
    |> Enum.map(&Database.relocate(&1, url))
  end

  def list_tables(db = %Database{}) do
    query = "SELECT table_name AS name FROM information_schema.tables WHERE " <>
      "table_schema = 'public'"

    results = query!(db.url, query, [])
    Enum.map(results.rows, &Repo.load(Table, {results.columns, &1}))
  end

  def describe_columns(db = %Database{}, table = %Table{}) do
    query = "SELECT column_name AS name, data_type " <>
      "from information_schema.columns WHERE table_name = $1"

    results = query!(db.url, query, [table.name])
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

  defp query!(url, query, params) do
    with_connection(
      url,
      fn(pid) -> Postgrex.query!(pid, query, params) end
    )
  end
end

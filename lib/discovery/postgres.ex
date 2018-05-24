defmodule Cromulon.Discovery.Postgres do
  defmodule ForeignKey do
    use Ecto.Schema

    @primary_key false
    schema "foreign_keys" do
      field(:from_table, :string)
      field(:from_column, :string)
      field(:to_table, :string)
      field(:uuid, :string)
    end
  end

  defmodule Column do
    use Ecto.Schema

    @primary_key false
    schema "columns" do
      field(:name, :string)
      field(:data_type, :string)
      field(:uuid, :string)
    end
  end

  defmodule Table do
    use Ecto.Schema

    @primary_key false
    schema "tables" do
      field(:name, :string)
      field(:uuid, :string)
      embeds_many(:columns, Cromulon.Discovery.Postgres.Column)
    end

    def tables_by_name(tables) do
      tables
      |> Enum.map(&{&1.name, &1})
      |> Enum.into(%{})
    end
  end

  defmodule Database do
    use Ecto.Schema

    alias Cromulon.Schema
    alias Cromulon.Schema.Edge
    alias Cromulon.Schema.Node
    alias Cromulon.Schema.Source

    @primary_key false
    schema "databases" do
      field(:url, :string)
      field(:name, :string)
      field(:uuid, :string)
      embeds_many(:tables, Cromulon.Discovery.Postgres.Table)
      embeds_many(:foreign_keys, Cromulon.Discovery.Postgres.ForeignKey)
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

    def to_schema(database) do
      source = %Source{
        name: database.name,
        connection_info: database.url,
        kind: "PostgreSQL database",
        uuid: Ecto.UUID.generate()
      }

      tables_schema = build_tables_schema(database.tables)
    end

    defp build_tables_schema(tables) do
      Enum.map(tables, fn table ->
        build_table_schema(table)
      end)
    end

    defp build_table_schema(table) do
      table_node = %Node{
        name: table.name,
        kind: "table",
        uuid: Ecto.UUID.generate()
      }

      column_nodes = Enum.map(table.columns, &column_node/1)
      edges = Enum.map(column_nodes, &column_edge(&1, table_node))

      {table_node, column_nodes, edges}
    end

    defp table_nodes(tables) do
      Enum.map(tables, fn table ->
        table_node(table)
      end)
    end

    defp column_node(column) do
      %Node{
        name: column.name,
        kind: "column",
        types: column.data_type,
        uuid: Ecto.UUID.generate()
      }
    end

    defp column_edge(column, table) do
      %Edge{
        from_uuid: column.uuid,
        to_uuid: table.uuid,
        uuid: Ecto.UUID.generate(),
        label: ":HAS_COLUMN"
      }
    end
  end

  alias Ecto.UUID
  alias Bolt.Sips, as: Bolt
  alias Cromulon.Repo
  alias Cromulon.Discovery.Postgres.Column
  alias Cromulon.Discovery.Postgres.Table

  alias Cromulon.Schema
  alias Cromulon.Schema.Source
  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Edge

  def describe_database(url) do
    source = describe_source(url)
    schemas = describe_schemas(source)

    tables_columns_fks =
      schemas
      |> Enum.filter(&Node.kind?(&1, "postgres schema"))
      |> Enum.flat_map(fn schema ->
        tables = describe_tables(source, schema)

        columns =
          tables
          |> Enum.filter(&Node.kind?(&1, "table"))
          |> Enum.flat_map(fn t -> describe_columns(source, schema, t) end)

        fks = find_fks(tables, columns)
        [tables, columns, fks]
      end)

    List.flatten([source, schemas, tables_columns_fks])
  end

  def describe_source(url) do
    parsed_url = URI.parse(url)
    "/" <> name = parsed_url.path

    %Source{
      name: name,
      connection_info: url,
      kind: "postgres database",
      uuid: UUID.generate()
    }
  end

  def describe_schemas(source = %Source{}) do
    node_uuid = UUID.generate()

    [
      %Node{
        name: "public",
        kind: "postgres schema",
        types: "table",
        uuid: node_uuid
      },
      %Edge{
        from_uuid: node_uuid,
        to_uuid: source.uuid,
        uuid: UUID.generate(),
        label: "SOURCE"
      }
    ]
  end

  def describe_tables(source = %Source{}, schema = %Node{kind: "postgres schema"}) do
    Enum.flat_map(list_tables(source.connection_info, schema.name), fn [table_name] ->
      node_uuid = UUID.generate()

      [
        %Node{
          name: table_name,
          kind: "table",
          types: "column",
          uuid: node_uuid
        },
        %Edge{
          from_uuid: node_uuid,
          to_uuid: schema.uuid,
          label: "TABLE"
        }
      ]
    end)
  end

  def describe_columns(
        source = %Source{},
        schema = %Node{kind: "postgres schema"},
        table = %Node{kind: "table"}
      ) do
    Enum.flat_map(list_columns(source.connection_info, schema.name, table.name), fn [
                                                                                      column_name,
                                                                                      column_type
                                                                                    ] ->
      node_uuid = UUID.generate()

      [
        %Node{
          name: column_name,
          kind: "column",
          types: column_type,
          uuid: node_uuid
        },
        %Edge{
          from_uuid: node_uuid,
          to_uuid: table.uuid,
          label: "COLUMN"
        }
      ]
    end)
  end

  defp find_fks(tables, columns) do
    table_nodes = Schema.select_nodes(tables)
    column_nodes = Schema.select_nodes(columns)

    column_nodes
    |> Enum.map(fn column_node -> find_column_fk_edge(column_node, table_nodes) end)
    |> Enum.filter(& &1)
  end

  defp find_column_fk_edge(column_node = %Node{kind: "column"}, table_nodes) do
    case find_fk_pair(column_node.name, table_nodes) do
      nil ->
        nil

      ftable ->
        %Edge{
          from_uuid: column_node.uuid,
          to_uuid: ftable.uuid,
          label: "FOREIGN_KEY"
        }
    end
  end

  defp list_tables(url, schema) do
    query =
      "SELECT table_name AS name FROM information_schema.tables WHERE " <> "table_schema = $1"

    results = query!(url, query, [schema])
    results.rows
  end

  defp list_columns(url, schema_name, table_name) do
    query =
      "SELECT column_name AS name, data_type " <>
        "from information_schema.columns WHERE table_name = $1 AND table_schema = $2"

    results = query!(url, query, [table_name, schema_name])
    results.rows
  end

  def crawl_database(db = %Database{}) do
    tables =
      Enum.map(list_tables(db), fn table ->
        %{table | columns: describe_columns(db, table)}
      end)

    db = %{db | tables: tables}
    fks = discover_foreign_keys(db)
    %{db | foreign_keys: fks}
  end

  def discover_foreign_keys(db = %Database{}) do
    table_names = Enum.map(db.tables, & &1.name)

    db.tables
    |> Enum.map(fn table -> table_foreign_keys(table, table_names) end)
    |> List.flatten()
    |> Enum.filter(& &1)
  end

  def table_foreign_keys(table, table_names) do
    Enum.map(table.columns, fn column ->
      case fk_table(column.name, table_names) do
        nil ->
          nil

        to_table ->
          %ForeignKey{from_table: table.name, from_column: column.name, to_table: to_table}
      end
    end)
  end

  def fk_table(column_name, tables) do
    case String.split(column_name, "_id") do
      [pre_id, ""] ->
        Enum.find(tables, fn t ->
          pre_id == t || Inflex.pluralize(pre_id) == t
        end)

      _ ->
        nil
    end
  end

  defp find_fk_pair(name, tables) do
    case potential_foreign_name(name) do
      nil ->
        nil

      fname ->
        Enum.find(tables, fn t ->
          fname == t.name || Inflex.pluralize(fname) == t.name
        end)
    end
  end

  defp potential_foreign_name(column_name) do
    case String.split(column_name, "_id") do
      [pre_id, ""] -> pre_id
      _ -> nil
    end
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

    for fk <- db.foreign_keys do
      merge_fk_to_graph(fk)
    end
  end

  def merge_table_to_graph(table, db) do
    conn = Bolt.conn()

    cypher = """
    MATCH (d:Database { name: $database, url: $url })
    MERGE (t:Table { name: $table })<-[:has_table]-(d)
    """

    Bolt.query!(conn, cypher, %{table: table.name, database: db.name, url: db.url})

    for column <- table.columns do
      params = %{
        table: table.name,
        database: db.name,
        column_name: column.name,
        data_type: column.data_type
      }

      cypher = """
      MERGE (c:Column { name: $column_name, data_type: $data_type, table_name: $table })
      """

      Bolt.query!(conn, cypher, params)

      cypher = """
      MATCH (t:Table { name: $table })
      MATCH (c:Column {name: $column_name, data_type: $data_type, table_name: $table })
      MERGE (t)-[:has_column]->(c)
      """

      Bolt.query!(conn, cypher, params)
    end
  end

  def merge_fk_to_graph(fk) do
    conn = Bolt.conn()

    cypher = """
    MATCH (t:Table { name: $to_table })
    MATCH (c:Column { name: $from_column, table_name: $from_table })
    MERGE (c) -[:foreign_key]-> (t)
    """

    params = %{
      to_table: fk.to_table,
      from_column: fk.from_column,
      from_table: fk.from_table
    }

    Bolt.query!(conn, cypher, params)
  end

  def list_databases(url) do
    query = "SELECT datname AS name FROM pg_database WHERE datistemplate = 'f'"

    results = query!(url, query, [])

    results.rows
    |> Enum.map(&Repo.load(Database, {results.columns, &1}))
    |> Enum.map(&Database.relocate(&1, url))
  end

  def list_tables(db = %Database{}) do
    query =
      "SELECT table_name AS name FROM information_schema.tables WHERE " <>
        "table_schema = 'public'"

    results = query!(db.url, query, [])
    Enum.map(results.rows, &Repo.load(Table, {results.columns, &1}))
  end

  def describe_columns(db = %Database{}, table = %Table{}) do
    query =
      "SELECT column_name AS name, data_type " <>
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
    with_connection(url, fn pid -> Postgrex.query!(pid, query, params) end)
  end
end

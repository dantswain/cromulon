defmodule Cromulon.Discovery.Postgres do
  alias Ecto.UUID
  alias Bolt.Sips, as: Bolt
  alias Cromulon.Repo
  alias Cromulon.Discovery.Postgres.Column
  alias Cromulon.Discovery.Postgres.Table

  alias Cromulon.Schema
  alias Cromulon.Schema.Source
  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Edge

  def get_identity(url) do
    query =
      "SELECT setting AS host, current_database() FROM pg_settings WHERE name = 'listen_addresses'"

    results = query!(url, query, [])
    [[host, database_name]] = results.rows
    "#{host}-#{database_name}"
  end

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

    [source, schemas, tables_columns_fks]
    |> List.flatten()
    |> Enum.map(&Schema.ensure_uuid(&1))
  end

  def describe_source(url) do
    parsed_url = URI.parse(url)
    "/" <> name = parsed_url.path

    identity = get_identity(url)

    %Source{
      name: name,
      connection_info: url,
      kind: "postgres database",
      uuid: UUID.generate(),
      identity: identity
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

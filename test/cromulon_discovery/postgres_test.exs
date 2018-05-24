defmodule CromulonDiscoveryTest.PostgresTest do
  use ExUnit.Case

  alias Bolt.Sips

  alias Cromulon.Discovery.Postgres, as: PGDiscovery
  alias Cromulon.Discovery.Postgres.Column
  alias Cromulon.Discovery.Postgres.Database
  alias Cromulon.Discovery.Postgres.Table

  alias Cromulon.Schema
  alias Cromulon.Schema.Source
  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Edge

  setup do
    conn = Sips.conn()
    Sips.query!(conn, "MATCH (n) DETACH DELETE n")

    on_exit(fn ->
      Sips.query!(conn, "MATCH (n) DETACH DELETE n")
    end)
  end

  def pg_url() do
    "postgres://postgres@localhost/postgres"
  end

  def url() do
    "postgres://postgres@localhost/cromulon_discovery_test"
  end

  def db() do
    Database.from_url(url())
  end

  def find_by_name(enum, name) do
    Enum.find(enum, fn
      {el, _} -> Map.get(el, :name) == name
      el -> Map.get(el, :name) == name
    end)
  end

  test "describe data source" do
    source = PGDiscovery.describe_source(url())
    assert is_binary(source.uuid)

    assert source == %Source{
             name: "cromulon_discovery_test",
             connection_info: url(),
             kind: "postgres database",
             attributes: %{},
             uuid: source.uuid
           }
  end

  test "describing pg schemas" do
    source = PGDiscovery.describe_source(url())
    [n, e] = PGDiscovery.describe_schemas(source)

    assert n == %Node{
             name: "public",
             kind: "postgres schema",
             types: "table",
             attributes: %{},
             uuid: n.uuid
           }

    assert e == %Edge{
             from_uuid: n.uuid,
             to_uuid: source.uuid,
             uuid: e.uuid,
             label: "SOURCE"
           }
  end

  test "describing pg tables" do
    source = PGDiscovery.describe_source(url())
    [schema, _source_schema] = PGDiscovery.describe_schemas(source)

    tables = PGDiscovery.describe_tables(source, schema)
    assert [%Node{}, %Edge{} | _] = tables

    for [n, e] <- Enum.chunk_every(tables, 2) do
      assert %Node{} = n
      assert %Edge{} = e
      assert e.from_uuid == n.uuid
      assert e.to_uuid == schema.uuid
      assert e.label == "TABLE"
      assert n.kind == "table"
      assert n.types == "column"
    end

    table_names =
      tables
      |> Schema.select_nodes()
      |> Enum.map(& &1.name)

    assert MapSet.new(table_names) == MapSet.new(["schema_migrations", "customers", "contacts"])
  end

  test "describing pg columns" do
    source = PGDiscovery.describe_source(url())
    [schema, _source_schema] = PGDiscovery.describe_schemas(source)
    tables = PGDiscovery.describe_tables(source, schema)

    customers_table = find_by_name(tables, "customers")
    columns = PGDiscovery.describe_columns(source, schema, customers_table)

    assert length(columns) == 10

    for [n, e] <- Enum.chunk_every(columns, 2) do
      assert %Node{} = n
      assert %Edge{} = e
      assert e.from_uuid == n.uuid
      assert e.to_uuid == customers_table.uuid
      assert e.label == "COLUMN"
      assert n.kind == "column"
    end

    c = find_by_name(columns, "id")
    assert c.types == "bigint"
    c = find_by_name(columns, "name")
    assert c.types == "character varying"
    c = find_by_name(columns, "address")
    assert c.types == "character varying"
    c = find_by_name(columns, "inserted_at")
    assert c.types == "timestamp without time zone"
    c = find_by_name(columns, "updated_at")
    assert c.types == "timestamp without time zone"
  end

  test "finding foreign keys" do
    full_schema = PGDiscovery.describe_database(url())

    fks =
      full_schema
      |> Schema.select_edges()
      |> Enum.filter(fn e -> e.label == "FOREIGN_KEY" end)

    assert length(fks) == 1

    [fk] = fks
    fk_from = Schema.find_by_uuid(full_schema, fk.from_uuid)
    fk_to = Schema.find_by_uuid(full_schema, fk.to_uuid)

    assert fk_from.name == "customer_id"
    assert fk_to.name == "customers"
  end

  test "Database from url" do
    assert db().url == url()
    assert db().name == "cromulon_discovery_test"
  end

  test "relocate Database" do
    relocated_db =
      Database.relocate(
        db(),
        "postgres://other_user@other_host/postgres"
      )

    assert %Database{
             name: "cromulon_discovery_test",
             url: "postgres://other_user@other_host/cromulon_discovery_test"
           } == relocated_db
  end

  test "listing databases" do
    databases = PGDiscovery.list_databases(pg_url())

    cromulon_test = find_by_name(databases, "cromulon_test")
    assert cromulon_test.url == "postgres://postgres@localhost/cromulon_test"

    cromulon_discovery_test = find_by_name(databases, "cromulon_discovery_test")
    assert cromulon_discovery_test.url == "postgres://postgres@localhost/cromulon_discovery_test"
  end

  test "listing tables in a database" do
    tables = PGDiscovery.list_tables(db())

    assert Enum.map(tables, & &1.name) == ["schema_migrations", "customers", "contacts"]
  end

  test "describing database tables" do
    columns = PGDiscovery.describe_columns(db(), %Table{name: "customers"})
    assert length(columns) == 5

    id = find_by_name(columns, "id")
    assert %Column{} = id
    assert id.data_type == "bigint"
  end

  test "crawling a database" do
    crawled_db = PGDiscovery.crawl_database(db())

    assert length(crawled_db.tables) == 3
    customers = find_by_name(crawled_db.tables, "customers")
    assert %Table{} = customers
    id = find_by_name(customers.columns, "id")
    assert %Column{} = id
  end

  test "discoverying foreign keys" do
    crawled_db = PGDiscovery.crawl_database(db())

    [fk] = crawled_db.foreign_keys
    assert fk.from_table == "contacts"
    assert fk.to_table == "customers"
    assert fk.from_column == "customer_id"
  end

  test "merging a database to the graph" do
    crawled_db = PGDiscovery.crawl_database(db())
    PGDiscovery.merge_database_to_graph(crawled_db)

    [n] =
      Sips.query!(Sips.conn(), "MATCH (d:Database { name: $name }) RETURN (d)", %{
        name: "cromulon_discovery_test"
      })

    assert n["d"].properties["url"] == url()

    [n] =
      Sips.query!(
        Sips.conn(),
        "MATCH (d:Database) -[:has_table]-> (t:Table {name: $name}) RETURN (t)",
        %{name: "customers"}
      )

    assert n["t"]

    [n] =
      Sips.query!(
        Sips.conn(),
        "MATCH (t:Table {name: $table_name}) -[:has_column]-> " <>
          "(c:Column {name: $column_name}) RETURN (c)",
        %{table_name: "customers", column_name: "name"}
      )

    assert n["c"].properties["data_type"] == "character varying"

    [r] =
      Sips.query!(
        Sips.conn(),
        "MATCH (c:Column) -[:foreign_key]-> (t:Table) RETURN (c), (t)"
      )

    assert r["c"].properties["name"] == "customer_id"
    assert r["t"].properties["name"] == "customers"
  end
end

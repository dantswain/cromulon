defmodule CromulonDiscoveryTest.PostgresTest do
  use ExUnit.Case

  alias Bolt.Sips

  alias Cromulon.Discovery.Postgres, as: PGDiscovery

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
             uuid: source.uuid,
             identity: "localhost-cromulon_discovery_test"
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
end

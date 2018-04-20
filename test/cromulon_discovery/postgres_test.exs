defmodule CromulonDiscoveryTest.PostgresTest do
  use ExUnit.Case

  alias Bolt.Sips

  alias Cromulon.Discovery.Postgres, as: PGDiscovery
  alias Cromulon.Discovery.Postgres.Column
  alias Cromulon.Discovery.Postgres.Database
  alias Cromulon.Discovery.Postgres.Table

  setup do
    conn = Sips.conn()
    Sips.query!(conn, "MATCH (n) DETACH DELETE n")

    on_exit fn ->
      Sips.query!(conn, "MATCH (n) DETACH DELETE n")
    end
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
    Enum.find(enum, fn(el) -> Map.get(el, :name) == name end)
  end

  test "Database from url" do
    assert db().url == url()
    assert db().name == "cromulon_discovery_test"
  end

  test "relocate Database" do
    relocated_db = Database.relocate(
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
    assert cromulon_discovery_test.url ==
      "postgres://postgres@localhost/cromulon_discovery_test"
  end

  test "listing tables in a database" do
    tables = PGDiscovery.list_tables(db())

    assert Enum.map(tables, &(&1.name)) == ["schema_migrations", "customers"]
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

    assert length(crawled_db.tables) == 2
    customers = find_by_name(crawled_db.tables, "customers")
    assert %Table{} = customers
    id = find_by_name(customers.columns, "id")
    assert %Column{} = id
  end

  test "merging a database to the graph" do
    crawled_db = PGDiscovery.crawl_database(db())
    PGDiscovery.merge_database_to_graph(crawled_db)

    [n] = Sips.query!(
      Sips.conn(),
      "MATCH (d:Database { name: $name }) RETURN (d)",
      %{name: "cromulon_discovery_test"}
    )
    assert n["d"].properties["url"] == url()

    [n] = Sips.query!(
      Sips.conn(),
      "MATCH (d:Database) -[:has_table]-> (t:Table {name: $name}) RETURN (t)",
      %{name: "customers"}
    )
    assert n["t"]

    [n] = Sips.query!(
      Sips.conn(),
      "MATCH (t:Table {name: $table_name}) -[:has_column]-> " <>
        "(c:Column {name: $column_name}) RETURN (c)",
      %{table_name: "customers", column_name: "name"}
    )
    assert n["c"].properties["data_type"] == "character varying"
   end
end

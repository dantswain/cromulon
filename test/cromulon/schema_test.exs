defmodule Cromulon.SchemaTest do
  use ExUnit.Case

  alias Bolt.Sips, as: Bolt

  alias Cromulon.Discovery.Postgres, as: PGDiscovery

  alias Cromulon.Schema
  alias Cromulon.Schema.Source
  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Edge

  setup do
    conn = Bolt.conn()
    Bolt.query!(conn, "MATCH (n) DETACH DELETE n")

    on_exit(fn ->
      Bolt.query!(conn, "MATCH (n) DETACH DELETE n")
    end)
  end

  def url() do
    "postgres://postgres@localhost/cromulon_discovery_test"
  end

  test "ingesting a schema" do
    conn = Bolt.conn()

    full_schema = PGDiscovery.describe_database(url())

    inserted = Schema.ingest(full_schema, conn)
    assert length(inserted) == length(full_schema)

    nodes = Schema.select_nodes(full_schema)
    edges = Schema.select_edges(full_schema)

    all_nodes = Bolt.query!(conn, "MATCH (n) RETURN n")
    assert length(all_nodes) == length(nodes) + 1  # +1 for the source
    all_edges = Bolt.query!(conn, "MATCH ()<-[r]-() RETURN r")
    assert length(all_edges) == length(edges)

    # should be idempotent
    inserted = Schema.ingest(full_schema, conn)
    assert length(inserted) == length(full_schema)

    all_nodes = Bolt.query!(conn, "MATCH (n) RETURN n")
    assert length(all_nodes) == length(nodes) + 1  # +1 for the source
    all_edges = Bolt.query!(conn, "MATCH ()<-[r]-() RETURN r")
    assert length(all_edges) == length(edges)
  end
end

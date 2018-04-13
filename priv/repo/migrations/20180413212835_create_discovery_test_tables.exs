defmodule CromulonDiscoveryTest.Repo.Migrations.CreateDiscoveryTestTables do
  use Ecto.Migration

  def change do
    create table("customers") do
      add :name, :string
      add :address, :string

      timestamps()
    end
  end
end

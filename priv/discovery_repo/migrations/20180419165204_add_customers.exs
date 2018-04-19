defmodule CromulonDiscoveryTest.Repo.Migrations.AddCustomers do
  use Ecto.Migration

  def change do
    def change do
      create table("customers") do
        add :name, :string
        add :address, :string

        timestamps()
      end
    end
  end
end

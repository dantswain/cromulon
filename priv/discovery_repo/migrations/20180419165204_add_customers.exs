defmodule CromulonDiscoveryTest.Repo.Migrations.AddCustomers do
  use Ecto.Migration

  def change do
    create table("customers") do
      add :name, :string
      add :address, :string

      timestamps()
    end

    create table("contacts") do
      add :name, :string
      add :phone_number, :string

      add :customer_id, references("customers")
    end
  end
end

defmodule ChatApp.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels) do
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :description, :string
      add :created_by, :string
      add :is_default, :boolean, default: false

      timestamps()
    end

    create unique_index(:channels, [:name])
  end
end

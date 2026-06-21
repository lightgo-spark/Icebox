defmodule ChatApp.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :text
      add :type, :string, null: false, default: "user"
      add :username, :string
      add :room, :string, null: false
      add :edited, :boolean, default: false
      add :deleted, :boolean, default: false
      add :file_url, :string
      add :file_name, :string

      timestamps()
    end

    create index(:messages, [:room])
    create index(:messages, [:inserted_at])
  end
end

defmodule ChatApp.Repo.Migrations.AddThreadsReactionsPins do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :thread_root_id, references(:messages, on_delete: :delete_all), null: true
      add :reactions, :text, default: "{}"
      add :reply_count, :integer, default: 0
      add :last_reply_at, :naive_datetime
    end

    create index(:messages, [:thread_root_id])

    create table(:pins) do
      add :channel_name, :string, null: false
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :pinned_by, :string, null: false
      timestamps()
    end

    create unique_index(:pins, [:message_id])
    create index(:pins, [:channel_name])
  end
end

defmodule ChatApp.Schemas.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :type, Ecto.Enum, values: [:user, :system], default: :user
    field :username, :string
    field :room, :string
    field :edited, :boolean, default: false
    field :deleted, :boolean, default: false
    field :file_url, :string
    field :file_name, :string
    field :thread_root_id, :integer
    field :reactions, :string, default: "{}"
    field :reply_count, :integer, default: 0
    field :last_reply_at, :naive_datetime
    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :content, :type, :username, :room,
      :edited, :deleted, :file_url, :file_name,
      :thread_root_id, :reactions, :reply_count, :last_reply_at
    ])
    |> validate_required([:type, :room])
    |> validate_length(:content, max: 2000)
  end
end

defmodule ChatApp.Schemas.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channels" do
    field :name, :string
    field :display_name, :string
    field :description, :string
    field :created_by, :string
    field :is_default, :boolean, default: false
    timestamps()
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :display_name, :description, :created_by, :is_default])
    |> validate_required([:name, :display_name])
    |> validate_format(:name, ~r/^[a-z0-9_-]+$/, message: "only lowercase letters, numbers, _ and - allowed")
    |> validate_length(:name, min: 1, max: 32)
    |> validate_length(:display_name, min: 1, max: 32)
    |> unique_constraint(:name)
  end
end

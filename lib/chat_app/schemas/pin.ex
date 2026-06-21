defmodule ChatApp.Schemas.Pin do
  use Ecto.Schema
  import Ecto.Changeset
  alias ChatApp.Schemas.Message

  schema "pins" do
    field :channel_name, :string
    belongs_to :message, Message
    field :pinned_by, :string
    timestamps()
  end

  def changeset(pin, attrs) do
    pin
    |> cast(attrs, [:channel_name, :message_id, :pinned_by])
    |> validate_required([:channel_name, :message_id, :pinned_by])
    |> unique_constraint(:message_id)
  end
end

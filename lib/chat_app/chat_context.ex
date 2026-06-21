defmodule ChatApp.ChatContext do
  @moduledoc "Channel and message DB context"
  import Ecto.Query
  alias ChatApp.Repo
  alias ChatApp.Schemas.{Message, Channel, Pin}

  # ── Channels ──────────────────────────────────

  def list_channels do
    Channel
    |> order_by([c], [desc: c.is_default, asc: c.inserted_at])
    |> Repo.all()
  end

  def get_channel_by_name(name), do: Repo.get_by(Channel, name: name)

  def create_channel(attrs) do
    %Channel{} |> Channel.changeset(attrs) |> Repo.insert()
  end

  def delete_channel(%Channel{is_default: true}), do: {:error, :cannot_delete_default}
  def delete_channel(%Channel{} = channel) do
    from(m in Message, where: m.room == ^channel.name) |> Repo.delete_all()
    from(p in Pin, where: p.channel_name == ^channel.name) |> Repo.delete_all()
    Repo.delete(channel)
  end

  # ── Messages (main list — excludes thread replies) ─────

  def list_messages(room, limit \\ 100) do
    Message
    |> where([m], m.room == ^room and is_nil(m.thread_root_id))
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  def list_messages_before(room, before_id, limit \\ 50) do
    Message
    |> where([m], m.room == ^room and m.id < ^before_id and is_nil(m.thread_root_id))
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  def has_messages_before?(room, before_id) do
    Message
    |> where([m], m.room == ^room and m.id < ^before_id and is_nil(m.thread_root_id))
    |> Repo.exists?()
  end

  def create_message(attrs) do
    %Message{} |> Message.changeset(attrs) |> Repo.insert()
  end

  def update_message(%Message{} = msg, attrs) do
    msg |> Message.changeset(attrs) |> Repo.update()
  end

  def soft_delete_message(%Message{} = msg) do
    msg
    |> Ecto.Changeset.change(deleted: true, content: "This message has been deleted.", edited: false)
    |> Repo.update()
  end

  def hard_delete_message(%Message{} = msg) do
    # Delete uploaded file from disk if present
    if msg.file_url do
      file_path = Path.join([:code.priv_dir(:chat_app), "static", String.trim_leading(msg.file_url, "/")])
      File.rm(file_path)
    end
    # Remove associated pins
    from(p in Pin, where: p.message_id == ^msg.id) |> Repo.delete_all()
    # Remove thread replies if this is a root message
    from(m in Message, where: m.thread_root_id == ^msg.id) |> Repo.delete_all()
    # Delete the message from DB
    Repo.delete(msg)
  end

  def get_message(id), do: Repo.get(Message, id)

  # ── Threads ────────────────────────────────────

  def list_thread_messages(root_id) do
    Message
    |> where([m], m.thread_root_id == ^root_id)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  def create_thread_reply(attrs) do
    root_id = attrs[:thread_root_id] || attrs["thread_root_id"]
    case %Message{} |> Message.changeset(attrs) |> Repo.insert() do
      {:ok, reply} ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        from(m in Message, where: m.id == ^root_id)
        |> Repo.update_all(inc: [reply_count: 1], set: [last_reply_at: now])
        {:ok, reply}
      err ->
        err
    end
  end

  # ── Reactions ────────────────────────────────────

  def toggle_reaction(msg_id, emoji, username) do
    msg = get_message(msg_id)
    reactions = decode_reactions(msg.reactions)
    users = Map.get(reactions, emoji, [])
    new_users =
      if username in users,
        do: List.delete(users, username),
        else: [username | users]
    new_reactions =
      if new_users == [],
        do: Map.delete(reactions, emoji),
        else: Map.put(reactions, emoji, new_users)
    msg
    |> Ecto.Changeset.change(reactions: Jason.encode!(new_reactions))
    |> Repo.update()
  end

  def decode_reactions(nil), do: %{}
  def decode_reactions(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, map} -> map
      _ -> %{}
    end
  end

  # ── Pinned messages ───────────────────────────────

  def list_pins(channel_name) do
    Pin
    |> where([p], p.channel_name == ^channel_name)
    |> preload(:message)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def pin_message(channel_name, msg_id, pinned_by) do
    case Repo.get_by(Pin, message_id: msg_id) do
      nil ->
        %Pin{}
        |> Pin.changeset(%{channel_name: channel_name, message_id: msg_id, pinned_by: pinned_by})
        |> Repo.insert()
      _ ->
        {:error, :already_pinned}
    end
  end

  def unpin_message(msg_id) do
    case Repo.get_by(Pin, message_id: msg_id) do
      nil -> {:error, :not_found}
      pin -> Repo.delete(pin)
    end
  end

  # ── Admin only ───────────────────────────────

  def clear_channel_messages(room) do
    from(m in Message, where: m.room == ^room) |> Repo.delete_all()
    from(p in Pin, where: p.channel_name == ^room) |> Repo.delete_all()
    :ok
  end

  def force_delete_channel(%Channel{} = channel) do
    from(m in Message, where: m.room == ^channel.name) |> Repo.delete_all()
    from(p in Pin, where: p.channel_name == ^channel.name) |> Repo.delete_all()
    Repo.delete(channel)
  end

  def count_messages(room) do
    Message
    |> where([m], m.room == ^room and is_nil(m.thread_root_id))
    |> Repo.aggregate(:count, :id)
  end

  # ── Search ──────────────────────────────────────

  def search_messages(room, query, limit \\ 50) do
    q = "%#{String.downcase(query)}%"
    Message
    |> where([m], m.room == ^room and is_nil(m.thread_root_id) and m.deleted == false)
    |> where([m], like(fragment("lower(?)", m.content), ^q))
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end
end

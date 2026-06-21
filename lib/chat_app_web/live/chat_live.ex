defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view

  alias ChatApp.{ChatContext, PresenceTracker}
  alias ChatApp.Schemas.Channel
  alias Phoenix.LiveView.JS

  # ══════════════════════════════════════════════════
  # Mount
  # ══════════════════════════════════════════════════
  @impl true
  def mount(_params, _session, socket) do
    channels = ChatContext.list_channels()
    ref = unique_ref()

    socket =
      socket
      |> assign(:channels, channels)
      |> assign(:room, "general")
      |> assign(:messages, [])
      |> assign(:username, nil)
      |> assign(:socket_ref, ref)
      |> assign(:show_username_modal, true)
      |> assign(:show_channel_modal, false)
      |> assign(:editing_id, nil)
      |> assign(:edit_content, "")
      |> assign(:online_users, [])
      |> assign(:typing_users, [])
      |> assign(:typing_timers, %{})
      |> assign(:unread_counts, %{})
      |> assign(:new_ch_name, "")
      |> assign(:new_ch_display, "")
      |> assign(:new_ch_desc, "")
      |> assign(:ch_error, nil)
      |> assign(:has_more, false)
      |> assign(:thread_open, false)
      |> assign(:thread_root, nil)
      |> assign(:thread_messages, [])
      |> assign(:pinned_messages, [])
      |> assign(:show_pins, false)
      |> assign(:search_open, false)
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:emoji_picker_id, nil)
      |> assign(:is_admin, false)
      |> assign(:show_admin_login, false)
      |> assign(:show_admin_panel, false)
      |> assign(:admin_tab, :users)
      |> assign(:admin_error, nil)
      |> assign(:admin_announce_text, "")
      |> assign(:banned_users, [])
      |> assign(:password_changed, false)
      |> assign(:password_error, nil)

    socket =
      allow_upload(socket, :image,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    if connected?(socket) do
      Enum.each(channels, fn ch ->
        Phoenix.PubSub.subscribe(ChatApp.PubSub, "chat:#{ch.name}")
        Phoenix.PubSub.subscribe(ChatApp.PubSub, "presence:#{ch.name}")
      end)
      Phoenix.PubSub.subscribe(ChatApp.PubSub, "channels")
      Phoenix.PubSub.subscribe(ChatApp.PubSub, "admin:global")
    end

    {:ok, socket}
  end

  # ══════════════════════════════════════════════════
  # Handle params (room navigation)
  # ══════════════════════════════════════════════════
  @impl true
  def handle_params(params, _url, socket) do
    all_names = Enum.map(socket.assigns.channels, & &1.name)
    new_room = Map.get(params, "room", "general")
    new_room = if new_room in all_names, do: new_room, else: "general"
    old_room = socket.assigns.room
    username = socket.assigns.username
    ref = socket.assigns.socket_ref

    if connected?(socket) and new_room != old_room and username do
      PresenceTracker.leave(old_room, ref)
      broadcast_presence(old_room)
      PresenceTracker.join(new_room, ref, username)
      broadcast_presence(new_room)
    end

    messages = if connected?(socket), do: ChatContext.list_messages(new_room), else: []
    online = PresenceTracker.get_users(new_room)
    pins = if connected?(socket), do: ChatContext.list_pins(new_room), else: []
    has_more = case messages do
      [first | _] -> ChatContext.has_messages_before?(new_room, first.id)
      _ -> false
    end

    {:noreply,
     socket
     |> assign(:room, new_room)
     |> assign(:messages, messages)
     |> assign(:online_users, online)
     |> assign(:pinned_messages, pins)
     |> assign(:editing_id, nil)
     |> assign(:edit_content, "")
     |> assign(:typing_users, [])
     |> assign(:has_more, has_more)
     |> assign(:thread_open, false)
     |> assign(:thread_root, nil)
     |> assign(:thread_messages, [])
     |> assign(:search_open, false)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> update(:unread_counts, &Map.put(&1, new_room, 0))}
  end

  # ══════════════════════════════════════════════════
  # Event: Set username
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("set_username", %{"username" => raw}, socket) do
    username = raw |> String.trim() |> String.slice(0, 20)
    room = socket.assigns.room
    ref = socket.assigns.socket_ref

    cond do
      username == "" ->
        {:noreply, put_flash(socket, :error, "Please enter a username.")}

      PresenceTracker.banned?(username) ->
        {:noreply, put_flash(socket, :error, "You are banned. Please contact an administrator.")}

      PresenceTracker.username_taken?(room, username) ->
        {:noreply, put_flash(socket, :error, "This username is already taken.")}

      true ->
        PresenceTracker.join(room, ref, username)
        broadcast_presence(room)
        broadcast_system(room, "#{username} has joined.")
        messages = ChatContext.list_messages(room)
        pins = ChatContext.list_pins(room)
        has_more = case messages do
          [first | _] -> ChatContext.has_messages_before?(room, first.id)
          _ -> false
        end

        {:noreply,
         socket
         |> assign(:username, username)
         |> assign(:show_username_modal, false)
         |> assign(:messages, messages)
         |> assign(:pinned_messages, pins)
         |> assign(:has_more, has_more)
         |> push_event("save_username", %{username: username})
         |> clear_flash()}
    end
  end

  @impl true
  def handle_event("restore_username", %{"username" => username}, socket) do
    if socket.assigns.username == nil and username != "" do
      room = socket.assigns.room
      ref = socket.assigns.socket_ref

      if PresenceTracker.banned?(username) or PresenceTracker.username_taken?(room, username) do
        {:noreply, socket}
      else
        PresenceTracker.join(room, ref, username)
        broadcast_presence(room)
        broadcast_system(room, "#{username} has joined.")
        messages = ChatContext.list_messages(room)
        pins = ChatContext.list_pins(room)
        has_more = case messages do
          [first | _] -> ChatContext.has_messages_before?(room, first.id)
          _ -> false
        end

        {:noreply,
         socket
         |> assign(:username, username)
         |> assign(:show_username_modal, false)
         |> assign(:messages, messages)
         |> assign(:pinned_messages, pins)
         |> assign(:has_more, has_more)
         |> push_event("save_username", %{username: username})}
      end
    else
      {:noreply, socket}
    end
  end

  # ══════════════════════════════════════════════════
  # Event: Send message
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("send_message", %{"message" => raw}, socket) do
    content = raw |> String.trim() |> String.slice(0, 2000)
    username = socket.assigns.username
    room = socket.assigns.room

    if username == nil do
      {:noreply, socket}
    else
      file_info =
        consume_uploaded_entries(socket, :image, fn %{path: tmp_path}, entry ->
          ext = Path.extname(entry.client_name)
          filename = "#{System.os_time(:millisecond)}_#{:rand.uniform(99999)}#{ext}"
          dest = Path.join([:code.priv_dir(:chat_app), "static", "uploads", filename])
          File.mkdir_p!(Path.dirname(dest))
          File.cp!(tmp_path, dest)
          {:ok, %{url: "/uploads/#{filename}", name: entry.client_name}}
        end)
        |> List.first()

      attrs =
        %{type: :user, username: username, room: room, content: content}
        |> maybe_add_file(file_info)

      if content != "" or file_info != nil do
        case ChatContext.create_message(attrs) do
          {:ok, msg} ->
            Phoenix.PubSub.broadcast(ChatApp.PubSub, "chat:#{room}", {:new_message, msg})
          _ -> nil
        end
      end

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  # ══════════════════════════════════════════════════
  # Event: Typing
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("typing", _, socket) do
    username = socket.assigns.username
    room = socket.assigns.room
    if username do
      Phoenix.PubSub.broadcast_from(
        ChatApp.PubSub, self(), "chat:#{room}", {:typing, username}
      )
    end
    {:noreply, socket}
  end

  # ══════════════════════════════════════════════════
  # Event: Load older messages
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("load_more", _, socket) do
    room = socket.assigns.room
    case socket.assigns.messages do
      [first | _] ->
        older = ChatContext.list_messages_before(room, first.id, 50)
        has_more = case older do
          [oldest | _] -> ChatContext.has_messages_before?(room, oldest.id)
          _ -> false
        end
        {:noreply,
         socket
         |> update(:messages, &(older ++ &1))
         |> assign(:has_more, has_more)}
      _ ->
        {:noreply, socket}
    end
  end

  # ══════════════════════════════════════════════════
  # Event: Change channel
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("change_room", %{"room" => room}, socket) do
    {:noreply, push_patch(socket, to: ~p"/room/#{room}")}
  end

  # ══════════════════════════════════════════════════
  # Event: Edit message
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    id = String.to_integer(id)
    msg = Enum.find(socket.assigns.messages, &(&1.id == id))
    if msg && msg.username == socket.assigns.username && !msg.deleted do
      {:noreply, socket |> assign(:editing_id, id) |> assign(:edit_content, msg.content)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_edit", %{"_id" => id, "content" => content}, socket) do
    id = String.to_integer(id)
    content = String.trim(content)

    if content != "" do
      case ChatContext.get_message(id) do
        nil -> nil
        msg ->
          case ChatContext.update_message(msg, %{content: content, edited: true}) do
            {:ok, updated} ->
              Phoenix.PubSub.broadcast(
                ChatApp.PubSub, "chat:#{socket.assigns.room}",
                {:message_updated, updated}
              )
            _ -> nil
          end
      end
    end

    {:noreply, socket |> assign(:editing_id, nil) |> assign(:edit_content, "")}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, socket |> assign(:editing_id, nil) |> assign(:edit_content, "")}
  end

  # ══════════════════════════════════════════════════
  # Event: Delete message
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    id = String.to_integer(id)
    username = socket.assigns.username
    is_admin = socket.assigns.is_admin
    case ChatContext.get_message(id) do
      nil -> nil
      msg when msg.username == username or is_admin ->
        case ChatContext.soft_delete_message(msg) do
          {:ok, updated} ->
            Phoenix.PubSub.broadcast(
              ChatApp.PubSub, "chat:#{socket.assigns.room}",
              {:message_updated, updated}
            )
          _ -> nil
        end
      _ -> nil
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("hard_delete_message", %{"id" => id}, socket) do
    if socket.assigns.is_admin do
      id = String.to_integer(id)
      case ChatContext.get_message(id) do
        nil -> nil
        msg ->
          room = msg.room
          case ChatContext.hard_delete_message(msg) do
            {:ok, _} ->
              Phoenix.PubSub.broadcast(
                ChatApp.PubSub, "chat:#{room}",
                {:message_hard_deleted, id}
              )
            _ -> nil
          end
      end
    end
    {:noreply, socket}
  end

  # ══════════════════════════════════════════════════
  # Event: Threads
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("open_thread", %{"id" => id}, socket) do
    id = String.to_integer(id)
    root = ChatContext.get_message(id)
    replies = ChatContext.list_thread_messages(id)
    {:noreply,
     socket
     |> assign(:thread_open, true)
     |> assign(:thread_root, root)
     |> assign(:thread_messages, replies)}
  end

  @impl true
  def handle_event("close_thread", _, socket) do
    {:noreply,
     socket
     |> assign(:thread_open, false)
     |> assign(:thread_root, nil)
     |> assign(:thread_messages, [])}
  end

  @impl true
  def handle_event("send_thread_reply", %{"message" => raw}, socket) do
    content = raw |> String.trim() |> String.slice(0, 2000)
    username = socket.assigns.username
    root = socket.assigns.thread_root
    room = socket.assigns.room

    if username && root && content != "" do
      attrs = %{
        type: :user, username: username, room: room,
        content: content, thread_root_id: root.id
      }
      case ChatContext.create_thread_reply(attrs) do
        {:ok, reply} ->
          updated_root = ChatContext.get_message(root.id)
          Phoenix.PubSub.broadcast(
            ChatApp.PubSub, "chat:#{room}",
            {:new_thread_reply, reply, updated_root}
          )
        _ -> nil
      end
    end

    {:noreply, socket}
  end

  # ══════════════════════════════════════════════════
  # Event: Reactions
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("toggle_reaction", %{"id" => id, "emoji" => emoji}, socket) do
    username = socket.assigns.username
    if username do
      id = String.to_integer(id)
      case ChatContext.toggle_reaction(id, emoji, username) do
        {:ok, updated} ->
          Phoenix.PubSub.broadcast(
            ChatApp.PubSub, "chat:#{socket.assigns.room}",
            {:message_updated, updated}
          )
        _ -> nil
      end
    end
    {:noreply, assign(socket, :emoji_picker_id, nil)}
  end

  @impl true
  def handle_event("toggle_emoji_picker", %{"id" => id}, socket) do
    id = String.to_integer(id)
    new_id = if socket.assigns.emoji_picker_id == id, do: nil, else: id
    {:noreply, assign(socket, :emoji_picker_id, new_id)}
  end

  # ══════════════════════════════════════════════════
  # Event: Pinned messages
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("pin_message", %{"id" => id}, socket) do
    username = socket.assigns.username
    room = socket.assigns.room
    id = String.to_integer(id)

    case ChatContext.pin_message(room, id, username || "anonymous") do
      {:ok, pin} ->
        msg = ChatContext.get_message(id)
        pin_with_msg = %{pin | message: msg}
        Phoenix.PubSub.broadcast(ChatApp.PubSub, "chat:#{room}", {:message_pinned, pin_with_msg})
        {:noreply, socket}
      {:error, :already_pinned} ->
        {:noreply, put_flash(socket, :error, "This message is already pinned.")}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unpin_message", %{"id" => id}, socket) do
    id = String.to_integer(id)
    room = socket.assigns.room

    case ChatContext.unpin_message(id) do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(ChatApp.PubSub, "chat:#{room}", {:message_unpinned, id})
        {:noreply, socket}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_pins", _, socket) do
    {:noreply, update(socket, :show_pins, &(!&1))}
  end

  # ══════════════════════════════════════════════════
  # Event: Search
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("toggle_search", _, socket) do
    if socket.assigns.search_open do
      {:noreply,
       socket
       |> assign(:search_open, false)
       |> assign(:search_query, "")
       |> assign(:search_results, [])}
    else
      {:noreply, assign(socket, :search_open, true)}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)
    results =
      if query != "",
        do: ChatContext.search_messages(socket.assigns.room, query),
        else: []
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)}
  end

  @impl true
  def handle_event("close_search", _, socket) do
    {:noreply,
     socket
     |> assign(:search_open, false)
     |> assign(:search_query, "")
     |> assign(:search_results, [])}
  end

  # ══════════════════════════════════════════════════
  # Event: Create/delete channel
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("toggle_channel_modal", _, socket) do
    {:noreply,
     socket
     |> update(:show_channel_modal, &(!&1))
     |> assign(:new_ch_name, "")
     |> assign(:new_ch_display, "")
     |> assign(:new_ch_desc, "")
     |> assign(:ch_error, nil)}
  end

  @impl true
  def handle_event("update_ch_field", %{"field" => field, "value" => value}, socket) do
    key = String.to_existing_atom("new_ch_#{field}")
    {:noreply, assign(socket, key, value)}
  end

  @impl true
  def handle_event("create_channel", _, socket) do
    username = socket.assigns.username || "anonymous"
    attrs = %{
      name: socket.assigns.new_ch_name |> String.trim() |> String.downcase(),
      display_name: socket.assigns.new_ch_display |> String.trim(),
      description: socket.assigns.new_ch_desc |> String.trim(),
      created_by: username,
      is_default: false
    }

    case ChatContext.create_channel(attrs) do
      {:ok, channel} ->
        Phoenix.PubSub.broadcast(ChatApp.PubSub, "channels", {:channel_created, channel})
        {:noreply,
         socket
         |> assign(:show_channel_modal, false)
         |> assign(:ch_error, nil)
         |> push_patch(to: ~p"/room/#{channel.name}")}

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        err_text = errors |> Map.values() |> List.flatten() |> Enum.join(", ")
        {:noreply, assign(socket, :ch_error, err_text)}
    end
  end

  @impl true
  def handle_event("delete_channel", %{"name" => name}, socket) do
    case ChatContext.get_channel_by_name(name) do
      nil -> {:noreply, socket}
      channel ->
        case ChatContext.delete_channel(channel) do
          {:ok, _} ->
            Phoenix.PubSub.broadcast(ChatApp.PubSub, "channels", {:channel_deleted, name})
            {:noreply, socket}
          {:error, :cannot_delete_default} ->
            {:noreply, put_flash(socket, :error, "Default channels cannot be deleted.")}
          _ ->
            {:noreply, socket}
        end
    end
  end

  # ══════════════════════════════════════════════════
  # Event: Admin
  # ══════════════════════════════════════════════════
  @impl true
  def handle_event("open_admin_login", _, socket) do
    {:noreply, socket |> assign(:show_admin_login, true) |> assign(:admin_error, nil)}
  end

  @impl true
  def handle_event("close_admin_login", _, socket) do
    {:noreply, socket |> assign(:show_admin_login, false) |> assign(:admin_error, nil)}
  end

  @impl true
  def handle_event("admin_login", %{"password" => pw}, socket) do
    expected = Application.get_env(:chat_app, :admin_password, "admin")
    if pw == expected do
      banned = PresenceTracker.list_banned()
      {:noreply,
       socket
       |> assign(:is_admin, true)
       |> assign(:show_admin_login, false)
       |> assign(:show_admin_panel, true)
       |> assign(:admin_tab, :users)
       |> assign(:banned_users, banned)
       |> assign(:admin_error, nil)}
    else
      {:noreply, assign(socket, :admin_error, "Incorrect password.")}
    end
  end

  @impl true
  def handle_event("admin_logout", _, socket) do
    {:noreply,
     socket
     |> assign(:is_admin, false)
     |> assign(:show_admin_panel, false)}
  end

  @impl true
  def handle_event("open_admin_panel", _, socket) do
    if socket.assigns.is_admin do
      banned = PresenceTracker.list_banned()
      {:noreply, socket |> assign(:show_admin_panel, true) |> assign(:banned_users, banned)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_admin_panel", _, socket) do
    {:noreply, assign(socket, :show_admin_panel, false)}
  end

  @impl true
  def handle_event("set_admin_tab", %{"tab" => tab}, socket) do
    tab_atom = case tab do
      "users" -> :users
      "announce" -> :announce
      "channels" -> :channels
      "stats" -> :stats
      "settings" -> :settings
      _ -> :users
    end
    {:noreply,
     socket
     |> assign(:admin_tab, tab_atom)
     |> assign(:password_changed, false)
     |> assign(:password_error, nil)}
  end

  @impl true
  def handle_event("admin_kick_user", %{"username" => username}, socket) do
    if socket.assigns.is_admin and username != socket.assigns.username do
      Phoenix.PubSub.broadcast(ChatApp.PubSub, "admin:global", {:admin_kick, username})
      broadcast_system(socket.assigns.room, "Admin has kicked #{username}.")
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("admin_ban_user", %{"username" => username}, socket) do
    if socket.assigns.is_admin and username != socket.assigns.username do
      PresenceTracker.ban_user(username)
      Phoenix.PubSub.broadcast(ChatApp.PubSub, "admin:global", {:admin_kick, username})
      broadcast_system(socket.assigns.room, "Admin has banned #{username}.")
      banned = PresenceTracker.list_banned()
      {:noreply, assign(socket, :banned_users, banned)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("admin_unban_user", %{"username" => username}, socket) do
    if socket.assigns.is_admin do
      PresenceTracker.unban_user(username)
      banned = PresenceTracker.list_banned()
      {:noreply, assign(socket, :banned_users, banned)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("admin_change_password", %{"current" => current, "new_password" => new_pw, "confirm" => confirm}, socket) do
    if socket.assigns.is_admin do
      expected = Application.get_env(:chat_app, :admin_password) || "admin"
      cond do
        current != expected ->
          {:noreply, socket |> assign(:password_error, "Current password is incorrect.") |> assign(:password_changed, false)}
        String.trim(new_pw) == "" ->
          {:noreply, socket |> assign(:password_error, "New password cannot be empty.") |> assign(:password_changed, false)}
        String.length(new_pw) < 3 ->
          {:noreply, socket |> assign(:password_error, "New password must be at least 3 characters.") |> assign(:password_changed, false)}
        new_pw != confirm ->
          {:noreply, socket |> assign(:password_error, "Passwords do not match.") |> assign(:password_changed, false)}
        true ->
          Application.put_env(:chat_app, :admin_password, new_pw)
          {:noreply, socket |> assign(:password_changed, true) |> assign(:password_error, nil)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_announce_text", %{"text" => text}, socket) do
    {:noreply, assign(socket, :admin_announce_text, text)}
  end

  @impl true
  def handle_event("admin_announce", %{"scope" => scope}, socket) do
    text = socket.assigns.admin_announce_text |> String.trim()
    if socket.assigns.is_admin and text != "" do
      rooms = case scope do
        "all" -> Enum.map(socket.assigns.channels, & &1.name)
        _ -> [socket.assigns.room]
      end
      Enum.each(rooms, fn room ->
        broadcast_system(room, "[Announcement] #{text}")
      end)
      {:noreply, assign(socket, :admin_announce_text, "")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("admin_clear_channel", %{"name" => name}, socket) do
    if socket.assigns.is_admin do
      ChatContext.clear_channel_messages(name)
      Phoenix.PubSub.broadcast(ChatApp.PubSub, "channels", {:channel_cleared, name})
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("admin_force_delete_channel", %{"name" => name}, socket) do
    if socket.assigns.is_admin do
      case ChatContext.get_channel_by_name(name) do
        nil -> nil
        channel ->
          case ChatContext.force_delete_channel(channel) do
            {:ok, _} ->
              Phoenix.PubSub.broadcast(ChatApp.PubSub, "channels", {:channel_deleted, name})
            _ -> nil
          end
      end
    end
    {:noreply, socket}
  end

  # ══════════════════════════════════════════════════
  # PubSub message handling
  # ══════════════════════════════════════════════════
  @impl true
  def handle_info({:new_message, msg}, socket) do
    if msg.room == socket.assigns.room and is_nil(msg.thread_root_id) do
      {:noreply, update(socket, :messages, fn msgs ->
        (msgs ++ [msg]) |> Enum.take(-200)
      end)}
    else
      {:noreply, update(socket, :unread_counts, fn counts ->
        Map.update(counts, msg.room, 1, &(&1 + 1))
      end)}
    end
  end

  @impl true
  def handle_info({:message_updated, msg}, socket) do
    if msg.room == socket.assigns.room do
      {:noreply, update(socket, :messages, fn msgs ->
        Enum.map(msgs, fn m -> if m.id == msg.id, do: msg, else: m end)
      end)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:message_hard_deleted, msg_id}, socket) do
    socket =
      socket
      |> update(:messages, fn msgs -> Enum.reject(msgs, &(&1.id == msg_id)) end)
      |> update(:pinned_messages, fn pins -> Enum.reject(pins, &(&1.message_id == msg_id)) end)

    socket =
      if socket.assigns.thread_open and socket.assigns.thread_root and
         socket.assigns.thread_root.id == msg_id do
        socket
        |> assign(:thread_open, false)
        |> assign(:thread_root, nil)
        |> assign(:thread_messages, [])
      else
        update(socket, :thread_messages, fn msgs -> Enum.reject(msgs, &(&1.id == msg_id)) end)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_thread_reply, reply, updated_root}, socket) do
    if reply.room == socket.assigns.room do
      socket = update(socket, :messages, fn msgs ->
        Enum.map(msgs, fn m -> if m.id == updated_root.id, do: updated_root, else: m end)
      end)
      if socket.assigns.thread_open and
         socket.assigns.thread_root and
         socket.assigns.thread_root.id == reply.thread_root_id do
        {:noreply,
         socket
         |> update(:thread_messages, &(&1 ++ [reply]))
         |> assign(:thread_root, updated_root)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:message_pinned, pin}, socket) do
    if pin.channel_name == socket.assigns.room do
      {:noreply, update(socket, :pinned_messages, &([pin | &1]))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:message_unpinned, msg_id}, socket) do
    {:noreply, update(socket, :pinned_messages, &Enum.reject(&1, fn p -> p.message_id == msg_id end))}
  end

  @impl true
  def handle_info({:presence_updated, {room, users}}, socket) do
    if room == socket.assigns.room do
      {:noreply, assign(socket, :online_users, users)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:typing, username}, socket) do
    if username == socket.assigns.username do
      {:noreply, socket}
    else
      timers = socket.assigns.typing_timers
      if old_timer = Map.get(timers, username) do
        Process.cancel_timer(old_timer)
      end
      new_timer = Process.send_after(self(), {:stop_typing, username}, 3000)
      {:noreply,
       socket
       |> update(:typing_users, fn users ->
         [username | Enum.reject(users, &(&1 == username))]
       end)
       |> assign(:typing_timers, Map.put(timers, username, new_timer))}
    end
  end

  @impl true
  def handle_info({:stop_typing, username}, socket) do
    {:noreply,
     socket
     |> update(:typing_users, fn users -> Enum.reject(users, &(&1 == username)) end)
     |> update(:typing_timers, fn t -> Map.delete(t, username) end)}
  end

  @impl true
  def handle_info({:channel_created, channel}, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ChatApp.PubSub, "chat:#{channel.name}")
      Phoenix.PubSub.subscribe(ChatApp.PubSub, "presence:#{channel.name}")
    end
    {:noreply, update(socket, :channels, fn chs -> chs ++ [channel] end)}
  end

  @impl true
  def handle_info({:admin_kick, username}, socket) do
    if socket.assigns.username == username do
      room = socket.assigns.room
      ref = socket.assigns.socket_ref
      PresenceTracker.leave(room, ref)
      broadcast_presence(room)
      {:noreply,
       socket
       |> assign(:username, nil)
       |> assign(:show_username_modal, true)
       |> assign(:is_admin, false)
       |> put_flash(:error, "You have been kicked by an administrator.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:channel_cleared, name}, socket) do
    if socket.assigns.room == name do
      {:noreply,
       socket
       |> assign(:messages, [])
       |> assign(:has_more, false)
       |> assign(:pinned_messages, [])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:channel_deleted, name}, socket) do
    channels = Enum.reject(socket.assigns.channels, &(&1.name == name))
    socket = assign(socket, :channels, channels)
    if socket.assigns.room == name do
      {:noreply, push_patch(socket, to: ~p"/")}
    else
      {:noreply, socket}
    end
  end

  # ══════════════════════════════════════════════════
  # Disconnect
  # ══════════════════════════════════════════════════
  @impl true
  def terminate(_reason, socket) do
    username = socket.assigns.username
    room = socket.assigns.room
    ref = socket.assigns.socket_ref

    if username do
      PresenceTracker.leave(room, ref)
      broadcast_presence(room)
      broadcast_system(room, "#{username} has left.")
    end

    :ok
  end

  # ══════════════════════════════════════════════════
  # Helper functions
  # ══════════════════════════════════════════════════
  defp unique_ref, do: :erlang.unique_integer([:positive]) |> Integer.to_string()

  defp broadcast_presence(room) do
    users = PresenceTracker.get_users(room)
    Phoenix.PubSub.broadcast(ChatApp.PubSub, "presence:#{room}", {:presence_updated, {room, users}})
  end

  defp broadcast_system(room, text) do
    case ChatContext.create_message(%{type: :system, username: "system", room: room, content: text}) do
      {:ok, msg} ->
        Phoenix.PubSub.broadcast(ChatApp.PubSub, "chat:#{room}", {:new_message, msg})
      _ -> nil
    end
  end

  defp maybe_add_file(attrs, nil), do: attrs
  defp maybe_add_file(attrs, %{url: url, name: name}) do
    Map.merge(attrs, %{file_url: url, file_name: name})
  end

  # @mention highlighting
  def render_content(nil), do: ""
  def render_content(content) when is_binary(content) do
    parts = Regex.split(~r/(@[a-zA-Z0-9_]+)/, content, include_captures: true)
    html =
      Enum.map_join(parts, "", fn
        "@" <> _ = mention ->
          safe = Phoenix.HTML.html_escape(mention) |> Phoenix.HTML.safe_to_string()
          "<span class=\"mention\">#{safe}</span>"
        text ->
          Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()
      end)
    Phoenix.HTML.raw(html)
  end

  # Reaction JSON decode
  def decode_reactions_view(nil), do: %{}
  def decode_reactions_view(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, map} -> map
      _ -> %{}
    end
  end

  def format_time(%NaiveDateTime{} = dt) do
    local = NaiveDateTime.add(dt, 9 * 3600, :second)
    "#{pad(local.hour)}:#{pad(local.minute)}"
  end
  def format_time(_), do: ""

  defp pad(n), do: String.pad_leading(Integer.to_string(n), 2, "0")

  def user_color(username) when is_binary(username) do
    colors = [
      "#FF6B6B","#FF8E53","#FFA552","#FFD166",
      "#06D6A0","#118AB2","#7B2D8B","#E63946",
      "#2A9D8F","#E9C46A","#F4A261","#264653",
      "#6A4C93","#1982C4","#8AC926","#FF595E"
    ]
    idx = username |> String.to_charlist() |> Enum.sum() |> rem(length(colors))
    Enum.at(colors, idx)
  end
  def user_color(_), do: "#888"

  def room_display(channels, name) do
    case Enum.find(channels, &(&1.name == name)) do
      %Channel{display_name: d} -> d
      _ -> name
    end
  end

  def room_desc(channels, name) do
    case Enum.find(channels, &(&1.name == name)) do
      %Channel{description: d} when not is_nil(d) -> d
      _ -> ""
    end
  end

  def typing_text([]), do: nil
  def typing_text([u]), do: "#{u} is typing..."
  def typing_text([u1, u2]), do: "#{u1}, #{u2} are typing..."
  def typing_text([u1, u2 | rest]) do
    "#{u1}, #{u2} and #{length(rest)} more are typing..."
  end
end

defmodule ChatApp.PresenceTracker do
  @moduledoc """
  Per-connection (ref) user tracking + ban list management.
  data: %{room => %{ref => username}}
  """
  use GenServer

  @table :chat_presence
  @ban_table :chat_bans

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def join(room, ref, username) do
    GenServer.call(__MODULE__, {:join, room, ref, username})
  end

  def leave(room, ref) do
    GenServer.cast(__MODULE__, {:leave, room, ref})
  end

  def get_users(room) do
    case :ets.lookup(@table, room) do
      [{^room, map}] -> map |> Map.values() |> Enum.uniq() |> Enum.sort()
      [] -> []
    end
  end

  def username_taken?(room, username) do
    get_users(room) |> Enum.member?(username)
  end

  # ── Ban list ─────────────────────────────
  def ban_user(username) do
    :ets.insert(@ban_table, {username, true})
  end

  def unban_user(username) do
    :ets.delete(@ban_table, username)
  end

  def banned?(username) do
    :ets.member(@ban_table, username)
  end

  def list_banned do
    :ets.tab2list(@ban_table) |> Enum.map(fn {u, _} -> u end) |> Enum.sort()
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    :ets.new(@ban_table, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:join, room, ref, username}, _from, state) do
    map = get_map(room)
    :ets.insert(@table, {room, Map.put(map, ref, username)})
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:leave, room, ref}, state) do
    map = get_map(room)
    updated = Map.delete(map, ref)
    if map_size(updated) == 0 do
      :ets.delete(@table, room)
    else
      :ets.insert(@table, {room, updated})
    end
    {:noreply, state}
  end

  defp get_map(room) do
    case :ets.lookup(@table, room) do
      [{^room, map}] -> map
      [] -> %{}
    end
  end
end

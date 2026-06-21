defmodule ChatApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ChatApp.Repo,
      {Phoenix.PubSub, name: ChatApp.PubSub},
      ChatApp.PresenceTracker,
      ChatAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ChatApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ChatAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

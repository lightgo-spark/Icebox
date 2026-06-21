import Config

config :chat_app, ChatAppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ChatAppWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: ChatApp.PubSub,
  live_view: [signing_salt: "xK8mN2pQ"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :chat_app, ecto_repos: [ChatApp.Repo]

config :chat_app, admin_password: System.get_env("ADMIN_PASSWORD") || "admin"

config :chat_app, ChatApp.Repo,
  database: Path.expand("../chat_app.db", __DIR__),
  pool_size: 5

config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(
      js/app.js
      --bundle
      --target=es2017
      --outdir=../priv/static/assets
      --external:/fonts/*
      --external:/images/*
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  css: [
    args: ~w(css/app.css --bundle --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"

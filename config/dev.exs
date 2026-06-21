import Config

config :chat_app, ChatAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "localdevsecretkeybase1234567890abcdefghijklmnopqrstuvwxyz1234567890",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    esbuild_css: {Esbuild, :install_and_run, [:css, ~w(--watch)]}
  ]

config :chat_app, ChatAppWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/chat_app_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, level: :debug
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

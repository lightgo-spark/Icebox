# LiveChat - Real-time Chat Application

A full-featured real-time chat application built with **Elixir**, **Phoenix LiveView**, and **SQLite**.

<img src="screenshots/login.png" alt="LiveChat Screenshot" width="800" align="left" />
<br clear="left" />

## Features

### Core Chat
- Real-time messaging via WebSocket (Phoenix PubSub)
- Multiple channels with create/delete support
- Username-based authentication with localStorage persistence
- Typing indicators with debounce
- @mention autocomplete with user highlighting
- Image upload and preview (JPG, PNG, GIF, WebP, up to 5MB)
- Message edit and soft-delete
- Unread message count per channel

### Threads & Reactions
- Threaded replies with dedicated side panel
- Inline emoji reactions (8 emojis)
- Reaction toggle with user list tooltip

### Pinned Messages & Search
- Pin/unpin messages per channel
- Full-text search within channel messages
- Pinned message bar with quick navigation

### Admin Panel
- Password-protected admin login (default: `admin`)
- **Users tab**: View online users, kick/ban/unban
- **Announce tab**: Send system announcements to current or all channels
- **Channels tab**: Clear history, force-delete channels (including defaults)
- **Stats tab**: Real-time dashboard (channels, users, messages, bans, pins)

### UI/UX
- Discord-inspired dark theme
- Responsive design with mobile sidebar toggle
- Color-coded user avatars
- Smooth animations and transitions

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend | Elixir 1.18+ / Phoenix 1.8 |
| Real-time | Phoenix LiveView 1.2 / PubSub |
| Database | SQLite3 (via Ecto + Exqlite) |
| HTTP Server | Bandit |
| Frontend | HEEx templates + Vanilla JS |
| CSS | Custom CSS (no framework) |
| Build | esbuild |

## Requirements

- Elixir 1.14+
- Erlang/OTP 26+

## Installation & Setup

```bash
# Clone or navigate to the project directory
cd elixir_chat

# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# Build assets
mix assets.setup
mix assets.build

# Start the server
mix phx.server
```

Or simply run `start.bat` on Windows.

## Usage

1. Open http://localhost:4000 in your browser
2. Enter a username to join
3. Start chatting in the **#General** channel
4. Use `@username` to mention other users
5. Click the shield icon to access the admin panel (password: `admin`)

## Project Structure

```
elixir_chat/
  lib/
    chat_app/
      application.ex          # OTP Application
      repo.ex                 # Ecto Repo (SQLite)
      chat_context.ex         # DB queries (channels, messages, pins, search)
      presence_tracker.ex     # ETS-based presence + ban list
      schemas/
        channel.ex            # Channel schema
        message.ex            # Message schema
        pin.ex                # Pin schema
    chat_app_web/
      endpoint.ex             # Phoenix Endpoint
      router.ex               # Routes
      live/
        chat_live.ex           # Main LiveView (all events)
        chat_live.html.heex    # Chat UI template
      components/
        layouts/
          root.html.heex       # Root HTML layout
          app.html.heex        # App layout
        error_html.ex          # Error pages
    chat_app_web.ex            # Web module macros
  assets/
    css/app.css                # All styles
    js/app.js                  # Hooks & client-side logic
  priv/
    repo/
      migrations/              # DB migrations
      seeds.exs                # Default channel seeds
  config/                      # Phoenix config
  mix.exs                      # Project & dependencies
```

## License

MIT

Copyright (c) 2026 lightgo (lightgo1230@gmail.com)

## Dependencies & Licenses

All dependencies use permissive open-source licenses (MIT / Apache 2.0) and are fully compatible with commercial use.

| Package | License |
|---------|---------|
| Phoenix | MIT |
| Phoenix LiveView | MIT |
| Ecto | Apache 2.0 |
| SQLite3 (Exqlite) | MIT |
| Bandit | MIT |
| Jason | Apache 2.0 |
| esbuild | MIT |

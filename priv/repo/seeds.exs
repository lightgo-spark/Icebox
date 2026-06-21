alias ChatApp.Repo
alias ChatApp.Schemas.Channel

default_channels = [
  %{name: "general",  display_name: "General",  description: "General chat for everyone",       is_default: true},
  %{name: "tech",     display_name: "Tech",     description: "Tech & development talk",         is_default: true},
  %{name: "random",   display_name: "Random",   description: "Talk about anything",             is_default: true},
  %{name: "announce", display_name: "Announce",  description: "Announcements & important news", is_default: true},
]

Enum.each(default_channels, fn attrs ->
  case Repo.get_by(Channel, name: attrs.name) do
    nil ->
      %Channel{} |> Channel.changeset(attrs) |> Repo.insert!()
      IO.puts("Channel created: ##{attrs.name}")
    _ ->
      IO.puts("Channel already exists: ##{attrs.name}")
  end
end)

# starship (prompt)

Cross-shell prompt; config at `~/.config/starship.toml` (stack-managed, whole-file).

| Command | What |
|---|---|
| `starship explain` | explain what the current prompt is showing |
| `starship config` | open the config in `$EDITOR` |
| `starship module <name>` | render one module (e.g. `git_branch`, `directory`) |
| `starship preset <name>` | print a built-in preset |
| `starship preset --list` | list available presets |
| `starship timings` | per-module render timing (debug a slow prompt) |

An apply overwrites `starship.toml`; keep machine-specific tweaks out of it.

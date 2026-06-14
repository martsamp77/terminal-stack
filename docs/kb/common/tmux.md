# tmux

## Sessions
| Command | What it does |
|---|---|
| `tmux new -s name` | start a new named session |
| `tmux new -A -s name` | attach if it exists, else create (best default) |
| `tmux ls` | list running sessions |
| `tmux attach -t name` / `tmux a -t name` | reattach |
| `tmux attach -d -t name` | reattach, kicking off any other client |
| `tmux kill-session -t name` | kill a named session |
| `tmux kill-server` | kill all sessions |

## Keys (prefix `Ctrl-b`)
| Key | What it does |
|---|---|
| `Ctrl-b d` | detach (leaves session running) |
| `Ctrl-b s` | switch between sessions (picker) |
| `Ctrl-b %` | split side by side (vertical) |
| `Ctrl-b "` | split top/bottom (horizontal) |
| `Ctrl-b arrow` | move between panes |
| `Ctrl-b x` | close current pane |
| `Ctrl-b z` | zoom current pane fullscreen (toggle) — great for logs |
| `Ctrl-b [` | scroll mode (`q` to quit) |
| `Ctrl-b c` | new window |
| `Ctrl-b n` / `Ctrl-b p` | next / previous window |
| `Ctrl-b 0-9` | jump to window by number |

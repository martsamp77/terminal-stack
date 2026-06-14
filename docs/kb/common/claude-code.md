# Claude Code helpers

zsh aliases / pwsh functions. Each `cc*` sets the WezTerm tab title while Claude runs.

| Shortcut | Full command | What it does |
|---|---|---|
| `cc` | `claude` | launch Claude Code |
| `ccc` | `claude --continue` | continue last conversation |
| `ccd` | `claude --dangerously-skip-permissions` | no permission prompts |
| `ccdc` | `claude --dangerously-skip-permissions --continue` | both |
| `ccr` | `claude --resume` | pick a past session to resume |
| `ccdr` | `claude --dangerously-skip-permissions --resume` | both |
| `cca` | `claude agents` | agents view |
| `ccs name` | tmux session `cc-name` running `claude --name name` | zsh only — Claude in tmux, survives disconnects; defaults to current dir name |

`ccnotify on` / `off` toggles the done/error toast (zsh + pwsh).

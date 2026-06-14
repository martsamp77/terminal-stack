# Stack management

| Command | What it does |
|---|---|
| `doc` | this knowledge base — fuzzy-find/open a topic (`doc -h` for all subcommands) |
| `ref` | alias for `doc` |
| `wzr [topic]` | WezTerm key reference (`doc wezterm/...`) |
| `ts-update` | fetch + show incoming commits, record rollback point, pull, re-apply configs |
| `ts-rollback` | undo the last `ts-update`: reset the clone to the recorded SHA, re-apply |
| `plain` | vanilla shell, no rc/profile (no oh-my-zsh/starship/aliases) — `exit` to return |
| `chezmoi diff` | preview pending config changes before an apply |
| `chezmoi apply -v` | apply config (run from inside WSL on Windows) |
| `chezmoi re-add ~/.zshrc` | capture a hand-edit of a managed file back into the repo |

## SSH (stack shortcut)
| Command | What it does |
|---|---|
| `ssht host [session]` | SSH + remote tmux attach/create in one shot (defaults to session `main`) |

See `doc common/ssh-config`, `doc common/github-keys`, `doc common/scp-rsync` for SSH details.

# Workspace navigation

| Command | What it does |
|---|---|
| `ws` | cd to the workspace — `$WORKSPACE_DIR` (zsh `~/.zshrc.local` / pwsh `profile.local.ps1`) if set, else autodetected |
| `wsp` | cd to the `*_Personal` / `*-Personal` sibling |
| `wspu` | cd to the `*_Public` / `*-Public` sibling |
| `z dirname` | zoxide — jump to any directory you've visited, from anywhere |
| `zi` | zoxide interactive picker when there are multiple matches |
| `zoxide-prune` | drop dead paths from zoxide's database (pwsh) |

Autodetect probes (first existing wins): `/mnt/c/DATA/Workspace`, `~/Documents/Workspace`, `~/workspace`, `~/Workspace` (pwsh also `C:\DATA\Workspace`).

# delta (git diff pager)

Wired into git by the stack's gitconfig include (`core.pager = delta`, `navigate = true`).

| Command | What |
|---|---|
| `git diff` / `git show` / `git log -p` | paged through delta automatically |
| `n` / `N` (in the pager) | jump to next / previous file |
| `delta a.txt b.txt` | diff two files directly |
| `git diff \| delta --side-by-side` | force side-by-side |
| `git diff \| delta --line-numbers` | show line numbers |

Config: `~/.config/git/terminal-stack.gitconfig` → `[delta] navigate = true`.

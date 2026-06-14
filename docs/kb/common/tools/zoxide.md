# zoxide (smarter cd)

Learns your most-used directories; jump by substring. Init is in the shell rc.

| Command | What |
|---|---|
| `z foo` | cd to the best match for "foo" |
| `z foo bar` | match on multiple keywords |
| `zi` | interactive picker (fzf) among matches |
| `z -` | back to the previous dir |
| `zoxide query foo` | show where `z foo` would go |
| `zoxide query -l` | list the database (ranked) |
| `zoxide remove <path>` | drop a dead entry |

Windows pwsh also has `zoxide-prune` to clear dead paths.

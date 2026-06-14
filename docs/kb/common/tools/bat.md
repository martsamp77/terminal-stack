# bat (cat with wings)

Aliased: `ccat` = `bat --paging=never` (we deliberately don't shadow `cat`).

| Command | What |
|---|---|
| `bat file` | view with syntax highlight + line numbers |
| `bat -p file` | plain — no decorations, good for piping |
| `bat -n file` | line numbers only |
| `bat -A file` | reveal whitespace / non-printables |
| `bat -r 10:20 file` | only lines 10–20 |
| `bat -l yaml file` | force a language |
| `cmd \| bat` | highlight piped output |
| `bat --diff file` | highlight changed lines |

In the pager: `j`/`k` or arrows scroll, `/` search, `q` quit.

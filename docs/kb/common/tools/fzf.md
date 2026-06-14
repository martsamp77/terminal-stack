# fzf (fuzzy finder)

Shell keys (integration loaded in the rc): `Ctrl-R` history · `Ctrl-T` file → command line · `Alt-C` cd (zsh).

| Usage | What |
|---|---|
| `fzf` | pick a line from stdin |
| `cmd \| fzf` | fuzzy-pick from any output |
| `nvim $(fzf)` | open a fuzzy-picked file |
| `fzf -m` | multi-select (Tab to mark) |
| `fzf -q 'foo'` | start with a query |
| `fzf --preview 'bat --color=always {}'` | preview pane |
| `fzf --height 40% --reverse` | inline, top-down |

Inside fzf: type to filter, arrows / `Ctrl-J`/`Ctrl-K` move, Enter select, Esc cancel.

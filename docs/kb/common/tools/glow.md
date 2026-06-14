# glow (markdown renderer)

Renders markdown in the terminal with Nerd Font glyphs. The `doc` viewer uses it.

| Command | What |
|---|---|
| `glow file.md` | render a file |
| `glow -p file.md` | render in a pager (scrollable) |
| `glow .` | TUI browser of markdown under cwd |
| `glow -s dark\|light file.md` | force a style |
| `glow -w 100 file.md` | wrap at 100 columns |
| `glow https://…/README.md` | render a remote markdown URL |

In the pager: arrows / `j`/`k` scroll, `e` edit, `q` quit. (`doc` wraps all this.)

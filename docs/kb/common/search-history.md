# Search & history

| Key / Command | What it does |
|---|---|
| `Ctrl-R` | fzf fuzzy-search shell history — replaces `history \| grep` |
| `Ctrl-T` | fzf fuzzy-find a file, insert its path into the command line |
| `Alt-C` | fzf fuzzy-find a directory and cd into it (zsh) |
| `ESC ESC` | prepend `sudo` to the current/previous command (zsh sudo plugin) |
| `rg pattern` | ripgrep — recursive grep, fast, skips .git/node_modules |
| `rg -i` / `rg -l` / `rg -n` | case-insensitive / files-with-matches / line numbers |
| `curl -s … \| jq .` | pretty-print / query JSON |

To search the docs themselves: `doc -g <pattern>`, or `doc cmd` to find a command and drop it on your prompt.

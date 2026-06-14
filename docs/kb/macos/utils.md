# macOS — utilities

| Command | What it does |
|---|---|
| `cmd \| pbcopy` | pipe command output to the clipboard |
| `pbpaste` | clipboard to stdout — `pbpaste \| jq .` etc. |
| `open .` | current directory in Finder |
| `open -a "App" file` | open a file with a specific app |
| `mdfind query` | Spotlight search from the CLI (`-name file.txt` for filenames) |
| `caffeinate -i cmd` | keep the Mac awake while a command runs |

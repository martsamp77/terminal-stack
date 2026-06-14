# ripgrep (rg)

Fast recursive grep — respects `.gitignore`, skips binaries.

| Command | What |
|---|---|
| `rg pattern` | recursive search from cwd |
| `rg -i pattern` | case-insensitive |
| `rg -w pattern` | whole word |
| `rg -l pattern` | files with matches only |
| `rg -C 3 pattern` | 3 lines of context (`-A`/`-B` for after/before) |
| `rg -t py pattern` | only python files (`rg --type-list`) |
| `rg -g '*.md' pattern` | glob filter |
| `rg --hidden --no-ignore pattern` | include hidden + ignored |
| `rg -o 'pat'` | print only the matched text |
| `rg 'foo' -r 'bar'` | preview a replacement (stdout only) |
| `rg --files \| rg name` | fuzzy over filenames |

# Rendered command references — every platform, every format

Everything in this folder (except this README) is **generated** by
`bash scripts/render-command-reference.sh`. Never edit these files by hand —
edit the markdown sources and re-render; the renderer reports each preview as
`rendered`/`unchanged`, and `--check` flags staleness.

| Folder | Source | Resolved as |
|---|---|---|
| `linux/` | `command-reference.md.tmpl` | `.chezmoi.os = "linux"` — byte-identical for **WSL and native Linux**, so one folder covers both |
| `macos/` | `command-reference.md.tmpl` | `.chezmoi.os = "darwin"` |
| `windows/` | `windows/command-reference.md` | no templating — byte-copies of the source and its committed `.txt`/`.html` twins |

Each folder carries the three formats the stack deploys: `.md` (Obsidian,
`ref`), `.txt` (console; byte-identical to the `.md`), `.html` (browser).

These previews exist so the *final* per-platform content — after chezmoi's
`{{ if eq/ne .chezmoi.os ... }}` sections resolve — is browsable in the
repository. On the machines themselves the same content lands in `~` /
`%USERPROFILE%` at apply/sync time; nothing in this folder is ever deployed
(`docs/**` is chezmoi-ignored). Staleness is warned (never auto-fixed) on
every POSIX `chezmoi apply` by `run_after_10-check-command-reference.sh`.

The template resolution here is a deliberate, minimal shadow of chezmoi's:
the renderer supports exactly the directive forms the template uses and fails
loudly on anything else, and its Linux output is byte-verified against real
`chezmoi execute-template` output. Rationale and trade-offs:
`docs/decisions.md` § command-reference twins.

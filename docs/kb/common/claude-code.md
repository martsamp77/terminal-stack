# Claude Code helpers

zsh aliases / pwsh functions. Each `cc*` sets the WezTerm tab title while Claude runs.

| Shortcut | Full command | What it does |
|---|---|---|
| `cc` | `claude` | launch Claude Code |
| `ccc` | `claude --continue` | continue last conversation |
| `ccd` | `claude --dangerously-skip-permissions` | no permission prompts |
| `ccdc` | `claude --dangerously-skip-permissions --continue` | both |
| `ccr` | `claude --resume` | pick a past session to resume |
| `ccdr` | `claude --dangerously-skip-permissions --resume` | both |
| `cca` | `claude agents` | agents view |
| `ccs name` | tmux session `cc-name` running `claude --name name` | zsh only — Claude in tmux, survives disconnects; defaults to current dir name |

`ccnotify on` / `off` toggles the done/error toast (zsh + pwsh).

## Local TTS (Kokoro / Chatterbox / edge)

Optional voice when **Claude Code** finishes (`Stop`) / errors (`StopFailure`) or **Cursor Agent** stops (`stop` hook). Same `~/.claude/tts.json`, same Kokoro voice. **Off by default.**

| Command | What it does |
|---|---|
| `cctts on` / `off` | Enable/disable TTS (re-applies; adds/removes hooks in Claude + Cursor) |
| `cctts test` | End-to-end synth + play test |
| `ts-config tts …` | Full control (engine, voice, templates, URLs) |

### Hook wiring

| App | Config | Hook script |
|---|---|---|
| Claude Code | `~/.claude/settings.json` | `cc-speak.sh` / `cc-speak.ps1` (WezTerm panes only) |
| Cursor Agent | `~/.cursor/hooks.json` | `cursor-tts.sh` / `cursor-tts.ps1` (no WezTerm guard) |

Both call shared **`cc-tts-notify`** → Kokoro → **`cc-tts-play`** (WSL uses `cmd.exe ffplay` for Windows audio). Spoken text is prefixed **`Claude.`** or **`Cursor.`** so you can tell which app finished.

### Prerequisites

- **Kokoro** (primary): OpenAI-compatible API on `http://127.0.0.1:8880` — e.g. `remsky/kokoro-fastapi-gpu` in Docker. The install wizard probes `/health` or `/v1/models` and offers to enable TTS when reachable.
- **Chatterbox** (optional energy): `travisvn/chatterbox-tts-api` on `http://127.0.0.1:8881`. Upload a cloned voice (e.g. `adam`) via the API voice library; energy maps to `exaggeration = 0.25 + energy`.
- **edge-tts** (fallback): `pip install edge-tts` — used when the primary engine fails and edge fallback is enabled in config.

The stack does **not** install Docker or these containers — only wires hooks and config.

### Config files

- `~/.claude/tts.json` — runtime settings (engine, voices, templates, debounce). Rendered from chezmoi `[data]` on apply; Windows mirror written by sync.
- `ccTtsEnabled` in chezmoi data gates whether `cc-speak` hooks appear in `settings.json`. `ts-config tts off` + apply removes them cleanly.

### Message modes

- **`template`** (default): short phrases like “Done in {project}. I'm waiting for you.”
- **`hook`**: try to read Claude's last assistant message from hook stdin JSON (truncated to `maxChars`); falls back to templates.

### WSL audio

Synthesis hits `localhost:8880` (Docker Desktop forwards). **Playback routes through Windows** (`pwsh.exe` + `cc-speak-play.ps1` → `ffplay` or WMP COM) so you hear output on the same headphones as Hermes — not WSL `aplay`.

### Verification

Test scripts are **separate from the Claude hook** (no `WEZTERM_PANE` guard):

| Command | Script |
|---|---|
| `ts-config tts test` | `~/.claude/hooks/cc-tts-test.sh` (WSL) / `cc-tts-test.ps1` (Windows) |
| Manual synth | `~/.claude/hooks/cc-tts-synth.sh "hello"` → prints output path |
| Manual play | `~/.claude/hooks/cc-tts-play.sh /path/to/file.mp3` |

On **WSL**, `cc-tts-play.sh` uses **`cmd.exe /c ffplay`** with Windows PATH (works right after `winget install Gyan.FFmpeg` without restarting WSL). Install via `winget install Gyan.FFmpeg` or `ts-config apps ffmpeg` on Windows. Optional in the bootstrap app picker as **ffmpeg**.

1. `ts-config tts on && chezmoi apply -v` — confirm `cc-speak` hooks in live `~/.claude/settings.json`.
2. `ts-config tts test` — hear `am_adam` (runs `cc-tts-test.sh`, not the hook).
3. Run `cc` in WezTerm; on Stop, hear the template phrase.
4. `ts-config tts off && chezmoi apply` — TTS hooks gone from Claude settings and Cursor hooks.

**Cursor:** after apply, confirm `~/.cursor/hooks.json` has a `stop` entry. Run a short Agent task; on stop you should hear the template phrase. Check **Settings → Hooks** or the Hooks output channel if it doesn't fire. Restart Cursor after the first deploy.

Skip at bootstrap: `TS_CC_TTS=off` or `skip`. Enable non-interactively: `TS_CC_TTS=on`.

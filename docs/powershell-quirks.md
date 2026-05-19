# PowerShell + WezTerm + Claude Code quirks

A field guide to the subtle Windows-side gotchas this stack works around. If something breaks and the symptom matches one of these, you'll find the fix here.

## CP437 mojibake after Claude Code exits

**Symptom.** After exiting Claude Code (`/exit` or Ctrl-D), the next pwsh prompt shows `Γ¥»` (or similar three-character mojibake) where the starship `❯` glyph should be.

**Cause.** Claude Code's TUI changes the Win32 console output code page during its runtime and doesn't restore it on exit. After exit, pwsh emits the UTF-8 bytes of `❯` (3 bytes: `0xE2 0x9D 0xAF`), but the console is now in CP437 (the legacy DOS code page). CP437 decodes those bytes as three separate characters: `Γ` `¥` `»`.

**Fix.** In `Invoke-Starship-PreCommand` in `$PROFILE`, restore UTF-8 console encoding at the start of every prompt cycle:

```powershell
if ([Console]::OutputEncoding.CodePage -ne 65001) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
}
```

Cheap (integer compare when codepage is already correct), defensive (heals state from any tool that misbehaves, not just CC), and runs early enough that the prompt's `❯` decodes correctly on the very first redraw after CC exit.

Commit: [`116087d`](../CHANGELOG.md).

## `Enable-TransientPrompt` cmdlet not found

**Symptom.** Fresh pwsh shows `Enable-TransientPrompt : The term 'Enable-TransientPrompt' is not recognized...` when sourcing `$PROFILE`.

**Cause.** PSReadLine documents `Enable-TransientPrompt`, but version **2.4.5** (the latest stable PSReadLine on Windows as of this stack's deployment) doesn't actually export the cmdlet. Only six commands are exported from the module: `Get-PSReadLineKeyHandler`, `Get-PSReadLineOption`, `PSConsoleHostReadLine`, `Remove-PSReadLineKeyHandler`, `Set-PSReadLineKeyHandler`, `Set-PSReadLineOption`. `Enable-TransientPrompt` may exist as an internal function in some PSReadLine builds, but not in 2.4.5.

**Fix.** Wrap the call in `Get-Command`:

```powershell
if (Get-Command Enable-TransientPrompt -ErrorAction SilentlyContinue) {
    Enable-TransientPrompt
}
```

Future PSReadLine versions that do export it will pick it up automatically; older versions skip gracefully.

## Backslashes in JSON paths get stripped twice

**Symptom.** Claude Code hooks fail with `The argument 'C:Users<you>.claudehookswez-tab-status.ps1' is not recognized as the name of a script file.` (Note: zero backslashes in the path.)

**Cause.** Two passes of backslash interpretation:

1. JSON parses `"C:\\\\Users\\\\..."` → `C:\\Users\\...` (string field after escape).
2. Claude Code's hook executor passes the resulting string through a POSIX-style shell layer that consumes each `\` as the start of an escape sequence (`\U` → `U`, `\m` → `m`, etc.).

The net effect: the path arrives at PowerShell with zero backslashes.

**Fix.** Use forward slashes in the JSON path:

```json
"command": "pwsh -NoLogo -NonInteractive -ExecutionPolicy Bypass -File C:/Users/__WIN_USER__/.claude/hooks/wez-tab-status.ps1 -State thinking"
```

PowerShell's `-File` accepts forward slashes on Windows. Forward slashes have no special meaning in any shell, so neither layer interprets them.

Commit: [`a63044a`](../CHANGELOG.md).

## Claude Code overwrites the tab title

**Symptom.** Our `cc` PowerShell wrapper sets the tab title to `cc • <project>` via OSC 0 (`Write-Host -NoNewline "ESC ]0;cc • myproject BEL"`). Claude Code launches, and the tab title changes to the conversation slug (e.g., `distinguish-claude-code-tabs-pwsh`).

**Cause.** Claude Code's TUI emits its own OSC 0 / OSC 2 with a conversation-derived title. OSC writes to `pane.title`, which is mutable. Last writer wins. Claude Code writes after our wrapper does.

**Fix.** Use `wezterm cli set-tab-title` to set `tab.tab_title` instead of `pane.title`. `tab.tab_title` is independent of OSC streams and Claude Code can't touch it. Our `format-tab-title` Lua already prefers `tab.tab_title` over `pane.title`.

```powershell
function Set-WezTabTitle([string]$title) {
    if ($env:WEZTERM_PANE) {
        & wezterm.exe cli set-tab-title $title 2>$null
    }
}
```

Commit: [`d291b92`](../CHANGELOG.md).

## Synthetic Ctrl+V doesn't reach Claude Code

**Symptom.** Wispr Flow's voice-dictation paste works in pwsh, but not in Claude Code. Other apps that simulate Ctrl+V (some clipboard managers, accessibility tools) also fail.

**Cause.** WezTerm's default Windows keybindings put paste on `Ctrl+Shift+V` and `Shift+Insert`. Not `Ctrl+V`. Plain pwsh handles `Ctrl+V` itself because PSReadLine has its own paste binding for that key. Claude Code's TUI has no equivalent — it expects WezTerm-originated bracketed-paste sequences, which only fire when WezTerm intercepts the paste key. Synthetic `Ctrl+V` from Wispr passes straight through.

**Fix.** Bind `Ctrl+V` in WezTerm to `PasteFrom 'Clipboard'`:

```lua
{ key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
```

Now WezTerm intercepts the synthetic Ctrl+V, performs a real paste, sends bracketed-paste sequences that Claude Code accepts.

Trade-off: `Ctrl+V` no longer enters visual-block mode in vim/nvim inside WezTerm. Use `Ctrl+Q` instead (vim's documented alternative).

Commit: [`2a3f527`](../CHANGELOG.md). Related upstream issue: [anthropics/claude-code#38620](https://github.com/anthropics/claude-code/issues/38620).

## Same-day backup file got clobbered

**Symptom.** You overwrite a file via the run_after sync hook on the same day twice. The second overwrite destroys the first backup, leaving you with no rollback to the original.

**Cause.** Naïve backup logic: `cp $dst $dst.bak.$today`. Same-day re-runs use the same target filename and overwrite.

**Fix.** Check for existing backup; suffix with `.1`, `.2`, etc:

```sh
bak="$dst.bak.$today"
if [ -e "$bak" ]; then
    n=1
    while [ -e "$dst.bak.$today.$n" ]; do n=$((n + 1)); done
    bak="$dst.bak.$today.$n"
fi
cp -p -- "$dst" "$bak"
```

This is hardened in `run_after_90-sync-windows.sh` as of the initial deployment. If you write your own scripts that write `.bak.YYYYMMDD` files, use the same pattern.

## `~/.local/bin` not on zsh PATH in Ubuntu

**Symptom.** You install something to `~/.local/bin` (or symlink something there — like `bat` from `batcat`), and `command -v` from zsh returns empty.

**Cause.** oh-my-zsh's default `~/.zshrc` template includes a commented-out `export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH`. It's intentional — different distros handle PATH differently, and you opt in. Ubuntu's default `~/.profile` adds `~/.local/bin` to PATH, but `.profile` isn't sourced by interactive zsh sessions.

**Fix.** Add an explicit PATH export inside our cli-tools marker block in `~/.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

It's the first line inside the block, runs every shell init, idempotent.

## Cross-shell quoting traps

Several different tool-invocation paths go through this stack:

| From | To | Quoting layer count |
|---|---|---|
| PowerShell tool | WezTerm-launched pwsh | 1 (PS arg parsing) |
| PowerShell tool | wsl.exe → bash | 2 (PS → wsl.exe → bash) |
| PowerShell tool | wsl.exe → bash → zsh | 3 |
| Claude Code hook | bash | 1 |
| Claude Code hook | pwsh -File → script | 2 |

Each layer eats some quoting. Symptoms when something is wrong:

- Variables come back empty (PS ate the `$var`).
- Backslashes disappear (POSIX shell ate the `\`).
- Newlines get converted (PS pipeline added CR before LF).
- `head -1` errors as "unknown option" (because `\r` was injected from CRLF stdin).

Defensive practices used in this stack:
- For shell commands invoked through PS, prefer single-quoted strings for arguments.
- For multi-line scripts, write to a tempfile in WSL native filesystem and execute that.
- Strip `\r` from any file edited via Windows-side tools that will be parsed by bash: `sed -i 's/\r$//' <file>`.
- For paths in JSON consumed by shell layers, use forward slashes.

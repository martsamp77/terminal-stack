$env:_ZO_ECHO = '1'
$env:_ZO_EXCLUDE_DIRS = 'C:\Windows\*;*\node_modules\*;*\.git\*;*\target\*;*\dist\*;*\build\*'

function zoxide-prune {
  zoxide query -l | Where-Object { -not (Test-Path $_) } | ForEach-Object { zoxide remove $_ }
}

# ---- workspace-nav-start ----
# Workspace navigation (mirrors the zsh ws* functions). $env:WORKSPACE_DIR
# (set in profile.local.ps1) wins; otherwise the first existing autodetect
# candidate. Resolved at call time so the local override always applies.
function Get-TsWorkspace {
    if ($env:WORKSPACE_DIR) { return $env:WORKSPACE_DIR }
    foreach ($d in @(
        'C:\DATA\Workspace',
        (Join-Path $env:USERPROFILE 'workspace'),
        (Join-Path $env:USERPROFILE 'Documents\Workspace')
    )) {
        if (Test-Path $d) { return $d }
    }
    return $null
}
# Sibling resolver: handles both Workspace_Personal and Workspace-Personal naming.
function Get-TsWorkspaceSibling([string]$Suffix) {
    $root = Get-TsWorkspace
    if (-not $root) { return $null }
    foreach ($d in @("${root}_${Suffix}", "${root}-${Suffix}")) {
        if (Test-Path $d) { return $d }
    }
    return $null
}
function ws {
    $r = Get-TsWorkspace
    if ($r) { Set-Location $r } else { Write-Warning 'ws: no workspace found — set $env:WORKSPACE_DIR in profile.local.ps1' }
}
function wsp {
    $r = Get-TsWorkspaceSibling 'Personal'
    if ($r) { Set-Location $r } else { Write-Warning 'wsp: no *_Personal sibling' }
}
function wspu {
    $r = Get-TsWorkspaceSibling 'Public'
    if ($r) { Set-Location $r } else { Write-Warning 'wspu: no *_Public sibling' }
}
# Project-specific shortcuts (wscalibra, wsnetsuite, …) belong in
# profile.local.ps1 — see profile.local.ps1.example.
# ---- workspace-nav-end ----

function Set-WezTabTitle([string]$title) {
    if (-not $env:WEZTERM_PANE) { return }
    & wezterm.exe cli set-tab-title $title 2>$null
    # Empty title marks CC exit in this pane -> restore the base background (OSC 11),
    # undoing the per-pane state tint set by the wez-tab-status hook.
    if (-not $title) {
        try {
            [Console]::Out.Write("$([char]27)]11;#1e1e2e$([char]7)")              # reset background
            [Console]::Out.Write("$([char]27)]1337;SetUserVar=cc_state=$([char]7)")  # clear tab state
        } catch {}
    }
}

function cc    { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude @args } finally { Set-WezTabTitle "" } }
function ccc   { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --continue @args } finally { Set-WezTabTitle "" } }
function ccd   { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --dangerously-skip-permissions @args } finally { Set-WezTabTitle "" } }
function ccdc  { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --dangerously-skip-permissions --continue @args } finally { Set-WezTabTitle "" } }
function ccr   { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --resume @args } finally { Set-WezTabTitle "" } }
function ccdr  { Set-WezTabTitle "cc • $(Split-Path -Leaf $PWD)"; try { claude --dangerously-skip-permissions --resume @args } finally { Set-WezTabTitle "" } }
function cca   { Set-WezTabTitle "cc • agents"; try { claude agents } finally { Set-WezTabTitle "" } }

# Escape hatch: vanilla pwsh, no profile (no starship/zoxide/aliases).
# Nested — `exit` drops back to the customized shell.
function plain { Set-WezTabTitle "plain • $(Split-Path -Leaf $PWD)"; try { pwsh -NoLogo -NoProfile @args } finally { Set-WezTabTitle "" } }

# ---- starship-stack-start ----

# Native console children (Claude Code, etc.) can SetConsoleOutputCP back to 437 on exit; [Console]::OutputEncoding caches and won't catch it, so probe the OS codepage directly.
if (-not ('Native.ConsoleCP' -as [type])) {
    Add-Type -Namespace Native -Name ConsoleCP -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint GetConsoleOutputCP();
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern bool SetConsoleOutputCP(uint wCodePageID);
'@ | Out-Null
}
[Native.ConsoleCP]::SetConsoleOutputCP(65001) | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

Invoke-Expression (&starship init powershell)
if (Get-Command Enable-TransientPrompt -ErrorAction SilentlyContinue) { Enable-TransientPrompt }

function Invoke-Starship-PreCommand {
    if ([Native.ConsoleCP]::GetConsoleOutputCP() -ne 65001) {
        [Native.ConsoleCP]::SetConsoleOutputCP(65001) | Out-Null
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    }
    $loc = $executionContext.SessionState.Path.CurrentLocation
    if ($loc.Provider.Name -eq 'FileSystem') {
        Write-Host -NoNewline "`e]7;file://localhost/$($loc.Path)`a"
        $leaf = Split-Path -Leaf $loc.Path
        if ([string]::IsNullOrEmpty($leaf)) { $leaf = $loc.Path }
        Write-Host -NoNewline "`e]0;pwsh • $leaf`a"
    }
}
# ---- starship-stack-end ----

# ---- cli-tools-start ----
# Default editor: micro (a nano alternative), when installed. git follows $EDITOR.
if (Get-Command micro -ErrorAction SilentlyContinue) { $env:EDITOR = 'micro' }

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

if (Get-Command eza -ErrorAction SilentlyContinue) {
    # Built-in `ls` is an alias to Get-ChildItem; remove before redefining as a function.
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons=always --git --group-directories-first @args }
    function ll { eza -l --icons=always --git --group-directories-first @args }
    function la { eza -la --icons=always --git --group-directories-first @args }
    function lt { eza --tree --icons=always --git --group-directories-first @args }
}

# Open the command reference (synced to %USERPROFILE% by the stack) plus the
# machine-local supplement (command-reference.local.md, untracked) if present.
function ref {
    $files = @((Join-Path $env:USERPROFILE 'command-reference.md'))
    $local = Join-Path $env:USERPROFILE 'command-reference.local.md'
    if (Test-Path $local) { $files += $local }
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        & bat --paging=always @files
    } elseif (Get-Command glow -ErrorAction SilentlyContinue) {
        foreach ($f in $files) { & glow $f }
    } else {
        foreach ($f in $files) { Get-Content $f }
    }
}
# ---- cli-tools-end ----

# ---- git-shortcuts-start ----
# Git muscle-memory, matching the zsh side (oh-my-zsh git plugin + stack
# overrides). gp always means PULL and gl always means LOG on this stack.
function gst { git status @args }
function gp  { git pull @args }
function gco { git checkout @args }
function gf  { git fetch @args }
function gl  { git log --oneline --graph --decorate -10 @args }
function gd  { git diff @args }
function ga  { git add @args }
function gb  { git branch @args }
# ---- git-shortcuts-end ----

# ---- terminal-stack-update-start ----
# Resolution order: -SourceDir → $env:TERMINAL_STACK_DIR → install.ps1 default
# ($env:USERPROFILE\terminal-stack). We deliberately do NOT consult
# `chezmoi source-path` here: on Windows that returns chezmoi's default
# sourceDir (~/.local/share/chezmoi) regardless of where the actual clone
# lives, because Windows users don't configure chezmoi.toml (the WSL side does).
function Resolve-TsSourceDir([string]$SourceDir) {
    if (-not $SourceDir) { $SourceDir = $env:TERMINAL_STACK_DIR }
    if (-not $SourceDir) { $SourceDir = Join-Path $env:USERPROFILE 'terminal-stack' }
    if (-not (Test-Path (Join-Path $SourceDir '.git'))) {
        Write-Warning "terminal-stack clone not found at $SourceDir. Pass -SourceDir <path> or re-run install.ps1."
        return $null
    }
    return $SourceDir
}

function Invoke-TsSync([string]$SourceDir) {
    $sync = Join-Path $SourceDir 'scripts\sync-windows.ps1'
    if (Test-Path $sync) {
        & $sync -SourceDir $SourceDir
    } else {
        Write-Warning "$sync not found; Windows-side dotfiles not applied."
    }
}

function Get-TsStateFile {
    Join-Path $env:LOCALAPPDATA 'terminal-stack\rollback-sha'
}

function Update-TerminalStack {
    [CmdletBinding()]
    param([string]$SourceDir)

    $SourceDir = Resolve-TsSourceDir $SourceDir
    if (-not $SourceDir) { return }

    & git -C $SourceDir fetch --quiet
    if ($LASTEXITCODE -ne 0) { Write-Warning 'git fetch failed; not applying.'; return }

    # '@{u}' must be quoted — pwsh would otherwise parse it as a hashtable.
    $incoming = & git -C $SourceDir log --oneline 'HEAD..@{u}' 2>$null
    if ($incoming) {
        Write-Host '==> incoming changes:'
        $incoming | ForEach-Object { Write-Host "  $_" }
        # Record the rollback point only when something is actually incoming —
        # a no-op re-run must not clobber the last real rollback point.
        $stateFile = Get-TsStateFile
        New-Item -ItemType Directory -Force -Path (Split-Path $stateFile) | Out-Null
        (& git -C $SourceDir rev-parse HEAD) | Set-Content $stateFile
        Write-Host "==> recorded rollback point: $(& git -C $SourceDir rev-parse --short HEAD) (ts-rollback to undo)"
        & git -C $SourceDir pull --ff-only
        if ($LASTEXITCODE -ne 0) { Write-Warning 'git pull failed; not applying.'; return }
    } else {
        Write-Host '==> already up to date'
    }
    Invoke-TsSync $SourceDir
}
Set-Alias -Name ts-update -Value Update-TerminalStack

# Undo the last ts-update: reset the clone to the recorded pre-update SHA and
# re-apply. Manual fallback (state file missing): README § Updating & rollback.
function Restore-TerminalStack {
    [CmdletBinding()]
    param([string]$SourceDir)

    $SourceDir = Resolve-TsSourceDir $SourceDir
    if (-not $SourceDir) { return }

    $stateFile = Get-TsStateFile
    if (-not (Test-Path $stateFile)) {
        Write-Warning "no recorded rollback point ($stateFile)."
        Write-Warning "Manual procedure: git -C $SourceDir reset --hard <sha>; scripts\sync-windows.ps1"
        return
    }
    $sha = (Get-Content $stateFile -First 1).Trim()
    & git -C $SourceDir rev-parse --verify --quiet "$sha^{commit}" *> $null
    if ($LASTEXITCODE -ne 0) { Write-Warning "recorded SHA $sha not found in $SourceDir."; return }

    # The clone may double as a dev checkout — never reset --hard over real work.
    if (& git -C $SourceDir status --porcelain) {
        Write-Warning "$SourceDir has uncommitted changes; refusing to reset --hard. Commit or stash first."
        return
    }
    Write-Host "==> resetting $SourceDir to $sha (recorded before last ts-update)"
    & git -C $SourceDir reset --hard $sha
    if ($LASTEXITCODE -ne 0) { return }
    Invoke-TsSync $SourceDir
    Write-Host '==> done. run ts-update to return to latest.'
}
Set-Alias -Name ts-rollback -Value Restore-TerminalStack
# ---- terminal-stack-update-end ----

# ---- claude-code-start ----
function ccnotify {
    param([string]$Action)
    $f = "$HOME\.claude\.toast-notify"
    switch ($Action) {
        'on'  { New-Item $f -ItemType File -Force | Out-Null; Write-Host 'CC toast: ON' }
        'off' { Remove-Item $f -ErrorAction SilentlyContinue; Write-Host 'CC toast: OFF' }
        default {
            if (Test-Path $f) { Write-Host 'CC toast: ON  (ccnotify off to disable)' }
            else              { Write-Host 'CC toast: OFF (ccnotify on  to enable)'  }
        }
    }
}
# ---- claude-code-end ----

# ---- wzr-start ----
function wzr {
    param([string]$Topic = '')
    $refDir = Join-Path $env:USERPROFILE '.wezterm-ref'

    if ($Topic -eq '' -or $Topic -eq 'list' -or $Topic -eq '-h') {
        if ($Topic -ne 'list') { Write-Host 'Usage: wzr <topic>  |  wzr list'; Write-Host '' }
        Write-Host 'Topics:'
        Get-ChildItem (Join-Path $refDir '*.txt') | ForEach-Object {
            Write-Host "  wzr $($_.BaseName)"
        }
        return
    }

    $file = Join-Path $refDir "$Topic.txt"
    if (-not (Test-Path $file)) {
        Write-Warning "wzr: no topic '$Topic' — run 'wzr list'"
        return
    }

    if (Get-Command bat -ErrorAction SilentlyContinue) {
        & bat --style=plain --paging=always $file
    } else {
        Get-Content $file
    }
}
# ---- wzr-end ----

# ---- editor-launch-start ----
# npp [files...] — open file(s) in Notepad++ (like `ws`, but launches an editor).
# Resolve the exe lazily and invoke with the call operator `&` (the install path
# has spaces, so it must be invoked, not run as a bare command). GUI app, so `&`
# returns to the prompt immediately rather than blocking.
function npp {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Paths)
    $exe = (Get-Command notepad++ -ErrorAction SilentlyContinue).Source
    if (-not $exe) {
        foreach ($c in @("$env:ProgramFiles\Notepad++\notepad++.exe",
                         "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe")) {
            if (Test-Path $c) { $exe = $c; break }
        }
    }
    if (-not $exe) {
        Write-Warning 'npp: Notepad++ not found — install it or add notepad++.exe to PATH'
        return
    }
    if (-not $Paths) { & $exe; return }
    # Resolve each arg against the current dir so relative paths open correctly;
    # a not-yet-existing path is passed through (Notepad++ opens a new buffer).
    $resolved = foreach ($p in $Paths) {
        $full = Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue
        if     ($full)                                 { $full.Path }
        elseif ([System.IO.Path]::IsPathRooted($p))    { $p }
        else                                           { Join-Path (Get-Location).Path $p }
    }
    & $exe @resolved
}
# ---- editor-launch-end ----

# ---- local-overrides-start ----
# Per-machine overrides (not synced by the stack). The Windows counterpart of
# ~/.zshrc.local — see profile.local.ps1.example. Keep this block last so
# local definitions win.
$tsLocalProfile = Join-Path (Split-Path $PROFILE) 'profile.local.ps1'
if (Test-Path $tsLocalProfile) { . $tsLocalProfile }
# ---- local-overrides-end ----

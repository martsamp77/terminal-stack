# Claude Code statusLine command — mirrors the Starship top line.
# Receives session JSON on stdin.  Writes a single coloured line to stdout.
#
# Prompt layout (mirrors starship.toml):
#   ╭─  <os-icon>   <dir>    <branch>  <git-status>  ··  user@host  <model>  <cost>  ─╮
#
# ANSI palette (terminal renders these dimmed, so bold codes give best contrast)
#   Cyan  = ESC[96m / bold = ESC[1;96m
#   Green = ESC[92m / bold = ESC[1;92m
#   Yellow= ESC[93m / bold = ESC[1;93m
#   Dark  = ESC[90m          (fill dots)
#   Reset = ESC[0m

param()

# ── Read stdin JSON ───────────────────────────────────────────────────────────
$raw   = $input | Out-String
$json  = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue

# ── Helpers ───────────────────────────────────────────────────────────────────
function c($code, $text) { "${`e}[${code}m${text}${`e}[0m" }

$ESC   = [char]27
function ansi($code, $text) { "$ESC[$($code)m$text${ESC}[0m" }

# ── Current directory from JSON (fall back to $PWD) ──────────────────────────
$cwd = $null
if ($json) {
    try { $cwd = $json.workspace.current_dir } catch {}
    if (-not $cwd) { try { $cwd = $json.cwd } catch {} }
}
if (-not $cwd) { $cwd = $PWD.Path }

# Truncate path: keep last 4 segments (mirrors truncation_length = 4)
$parts    = $cwd -replace '\\','/' -split '/' | Where-Object { $_ -ne '' }
$maxSegs  = 4
if ($parts.Count -gt $maxSegs) {
    $parts = @('…') + $parts[-($maxSegs - 1)..-1]
}
$shortDir = $parts -join '/'

# ── Git info (run in the actual cwd directory) ────────────────────────────────
$branch    = ''
$gitStatus = ''
try {
    Push-Location $cwd -ErrorAction Stop

    $branchRaw = & git -c core.quotepath=false --no-optional-locks rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $branchRaw) {
        $branch = $branchRaw.Trim()

        # Porcelain v2 for status counts
        $porcelain = & git -c core.quotepath=false --no-optional-locks status --porcelain=v2 --branch 2>$null
        $modified  = ($porcelain | Where-Object { $_ -match '^[12] [.MADRCU][MADRCU]' }).Count
        $untracked = ($porcelain | Where-Object { $_ -match '^\?' }).Count
        $staged    = ($porcelain | Where-Object { $_ -match '^[12] [MADRCU]\.' }).Count
        $deleted   = ($porcelain | Where-Object { $_ -match '^[12] .D' }).Count

        # Ahead/behind from porcelain v2 header
        $abLine    = $porcelain | Where-Object { $_ -match '^# branch.ab' } | Select-Object -First 1
        $ahead = 0; $behind = 0
        if ($abLine -match '\+(\d+)\s+-(\d+)') { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2] }

        $parts2 = @()
        if ($staged    -gt 0) { $parts2 += "+$staged" }
        if ($modified  -gt 0) { $parts2 += "~$modified" }
        if ($untracked -gt 0) { $parts2 += "?$untracked" }
        if ($deleted   -gt 0) { $parts2 += "-$deleted" }
        if ($ahead     -gt 0) { $parts2 += [char]0x21C1 + "$ahead" }    # ⇡
        if ($behind    -gt 0) { $parts2 += [char]0x21E3 + "$behind" }   # ⇣
        if ($parts2.Count -gt 0) { $gitStatus = $parts2 -join ' ' }
    }
}
catch {}
finally {
    try { Pop-Location -ErrorAction SilentlyContinue } catch {}
}

# ── Model and session cost (right side extra, from JSON) ─────────────────────
$modelName = ''
$costUsd   = $null
if ($json) {
    try { $modelName = $json.model.display_name } catch {}
    try {
        # Try several candidate paths — field name varies across Claude Code versions
        foreach ($path in @('stats.total_cost_usd','session.total_cost_usd','total_cost_usd','cost_usd','costUsd')) {
            $val = $json
            foreach ($seg in $path -split '\.') { $val = $val.$seg }
            if ($null -ne $val) { $costUsd = [double]$val; break }
        }
    } catch {}
    # Uncomment to inspect raw JSON: $raw | Out-File "$env:TEMP\cc-status-debug.json" -Encoding utf8
}

# ── User and hostname ─────────────────────────────────────────────────────────
$user = $env:USERNAME
if (-not $user) { $user = & whoami 2>$null; $user = ($user -split '\\')[-1] }
$host_ = $env:COMPUTERNAME
if (-not $host_) { $host_ = [System.Net.Dns]::GetHostName() }

# ── Assemble segments ─────────────────────────────────────────────────────────
$G  = '1;92'   # bold green
$C  = '1;96'   # bold cyan
$Y  = '1;93'   # bold yellow
$DK = '90'     # dark gray (fill)
$R  = '0'      # reset

# OS icon: Windows  (U+E70F, Nerd Font)
$osIcon = [char]0xE70F

# Directory glyph:  (U+F07C folder, Nerd Font)
$dirGlyph = [char]0xF07C

# Branch glyphs: octocat  (U+E045 Nerd Font) + branch  (U+E0A0 Nerd Font)
$octocat     = [char]0xE045
$branchGlyph = [char]0xE0A0

# Build the visible content pieces
$leftParts  = @()
$leftParts += "${ESC}[${G}m" + [char]0x256D + [char]0x2500 + ' ' + "${ESC}[${R}m"           # ╭─
$leftParts += "${ESC}[${C}m" + "$osIcon " + "${ESC}[${R}m"                                    # OS icon
$leftParts += "${ESC}[${C}m" + " $dirGlyph  $shortDir" + "${ESC}[${R}m"                      # dir

if ($branch) {
    $leftParts += "${ESC}[${G}m" + "  $octocat $branchGlyph $branch" + "${ESC}[${R}m"        # git branch
    if ($gitStatus) {
        $leftParts += ' ' + "${ESC}[${Y}m" + $gitStatus + "${ESC}[${R}m"                     # git status
    }
}

$rightParts = @()
$rightParts += "${ESC}[${G}m" + "$user" + "${ESC}[${R}m"                                     # user
$rightParts += "${ESC}[${G}m" + '@' + "${ESC}[${R}m"                                         # @
$rightParts += "${ESC}[${G}m" + "$host_" + "${ESC}[${R}m"                                    # host
if ($modelName) {
    $rightParts += ' ' + "${ESC}[${C}m" + "$modelName" + "${ESC}[${R}m"                      # model
}
if ($null -ne $costUsd) {
    $costStr = '$' + ('{0:F4}' -f $costUsd)
    $rightParts += ' ' + "${ESC}[${DK}m" + $costStr + "${ESC}[${R}m"                         # session cost
}
$rightParts += "${ESC}[${G}m" + ' ' + [char]0x2500 + [char]0x256E + "${ESC}[${R}m"           # ─╮

$left  = $leftParts  -join ''
$right = $rightParts -join ''

# ── Fill dots between left and right ─────────────────────────────────────────
# Strip ANSI escapes to measure printable width
function Strip-Ansi([string]$s) { $s -replace '\x1B\[[0-9;]*m', '' }

$leftLen  = (Strip-Ansi $left).Length
$rightLen = (Strip-Ansi $right).Length

# Aim for total width; clamp fill to at least 1 dot
try { $termWidth = [Console]::WindowWidth } catch { $termWidth = 120 }
if ($termWidth -le 0) { $termWidth = 120 }

$fillLen = $termWidth - $leftLen - $rightLen - 1
if ($fillLen -lt 1) { $fillLen = 1 }
$fill = "${ESC}[${DK}m" + ('.' * $fillLen) + "${ESC}[${R}m"

# ── Output ────────────────────────────────────────────────────────────────────
Write-Host -NoNewline ($left + $fill + $right)

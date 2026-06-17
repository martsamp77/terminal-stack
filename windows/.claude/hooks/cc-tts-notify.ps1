param(
    [Parameter(Mandatory)][ValidateSet('waiting', 'error')][string]$State,
    [string]$OverrideText,
    [string]$ProjectDir,
    [string]$Prefix
)

$configPath = Join-Path $env:USERPROFILE '.claude\tts.json'
if (-not (Test-Path -LiteralPath $configPath)) { exit 1 }
$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if (-not $cfg.enabled) { exit 0 }
if ($cfg.events -notcontains $State) { exit 0 }

$project = if ($ProjectDir) {
    Split-Path -Leaf $ProjectDir
} elseif ($env:CURSOR_PROJECT_DIR) {
    Split-Path -Leaf $env:CURSOR_PROJECT_DIR
} elseif ($env:CLAUDE_PROJECT_DIR) {
    Split-Path -Leaf $env:CLAUDE_PROJECT_DIR
} else {
    Split-Path -Leaf $PWD
}

$text = if ($OverrideText) {
    $OverrideText
} else {
    ($cfg.templates.$State -replace '\{project\}', $project)
}
$text = ($text -replace "[\r\n]+", ' ').Trim()
if ($Prefix) { $text = "$Prefix. $text" }
if ($text.Length -gt $cfg.maxChars) { $text = $text.Substring(0, $cfg.maxChars) }

$k = $cfg.kokoro
$ext = if ($k.format) { $k.format } else { 'mp3' }
$out = Join-Path $env:TEMP ("cc-tts-{0}.{1}" -f [guid]::NewGuid().ToString('N'), $ext)

try {
    $body = @{
        model           = 'kokoro'
        input           = $text
        voice           = $k.voice
        response_format = $k.format
        speed           = [double]$k.speed
    } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri ($k.url.TrimEnd('/') + '/v1/audio/speech') `
        -Method Post -ContentType 'application/json' -Body $body `
        -TimeoutSec $k.timeoutSec -OutFile $out
    if (-not (Test-Path -LiteralPath $out) -or (Get-Item $out).Length -eq 0) { exit 1 }
    $play = Join-Path $env:USERPROFILE '.claude\hooks\cc-tts-play.ps1'
    if (Test-Path -LiteralPath $play) { & $play -MediaPath $out; exit 0 }
    if (Get-Command ffplay -ErrorAction SilentlyContinue) {
        & ffplay -nodisp -autoexit -hide_banner -loglevel quiet $out 2>$null
    }
} finally {
    Remove-Item $out -ErrorAction SilentlyContinue
}

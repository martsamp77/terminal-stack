# cc-tts-test.ps1 — end-to-end TTS test (synth + play).
param(
    [string]$Source = 'test',
    [string]$Phrase = ''
)

. (Join-Path $PSScriptRoot 'cc-tts-lib.ps1')

$configPath = Join-Path $env:USERPROFILE '.claude\tts\config.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    $configPath = Join-Path $env:USERPROFILE '.claude\tts.json'
}
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Error "Missing TTS config — run sync-windows or chezmoi apply"
    exit 1
}

$cfg = Initialize-CcTtsConfig
$k = $cfg.kokoro
Write-Host "cc-tts-test: source=$Source kokoro $($k.url) voice $($k.voice)"

try {
    $r = Invoke-WebRequest -Uri ($k.url.TrimEnd('/') + '/health') -TimeoutSec 2 -UseBasicParsing
    Write-Host "cc-tts-test: kokoro up ($($r.StatusCode))"
} catch {
    Write-Warning 'cc-tts-test: kokoro not reachable'
}

if (-not $Phrase) {
    $Phrase = Build-CcTtsSpeech -Source $Source -State waiting -Project (Split-Path -Leaf $PWD) -OverrideText ''
}
if (-not $Phrase) { $Phrase = 'Terminal stack TTS test.' }

Write-Host "cc-tts-test: phrase=$Phrase"
& (Join-Path $PSScriptRoot 'cc-tts-notify.ps1') -State waiting -Source $Source -OverrideText $Phrase -Foreground
Write-Host 'cc-tts-test: done.'

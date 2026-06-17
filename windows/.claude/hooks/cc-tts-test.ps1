# cc-tts-test.ps1 — end-to-end TTS test (synth + play). No WezTerm guards.
param([string]$Phrase = 'Terminal stack TTS test.')

$configPath = Join-Path $env:USERPROFILE '.claude\tts.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Error "Missing $configPath — run sync-windows or chezmoi apply"
    exit 1
}

$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$k = $cfg.kokoro
Write-Host "cc-tts-test: kokoro $($k.url) voice $($k.voice)"

try {
    $r = Invoke-WebRequest -Uri ($k.url.TrimEnd('/') + '/health') -TimeoutSec 2 -UseBasicParsing
    Write-Host "cc-tts-test: kokoro up ($($r.StatusCode))"
} catch {
    Write-Warning "cc-tts-test: kokoro not reachable"
}

$ext = if ($k.format) { $k.format } else { 'mp3' }
$out = Join-Path $env:TEMP ("cc-tts-test-{0}.{1}" -f [guid]::NewGuid().ToString('N'), $ext)

try {
    $body = @{
        model           = 'kokoro'
        input           = $Phrase
        voice           = $k.voice
        response_format = $k.format
        speed           = [double]$k.speed
    } | ConvertTo-Json -Compress

    Write-Host 'cc-tts-test: synthesizing…'
    Invoke-RestMethod -Uri ($k.url.TrimEnd('/') + '/v1/audio/speech') `
        -Method Post -ContentType 'application/json' -Body $body `
        -TimeoutSec $k.timeoutSec -OutFile $out

    if (-not (Test-Path -LiteralPath $out) -or (Get-Item $out).Length -eq 0) {
        throw 'empty output file'
    }
    Write-Host "cc-tts-test: wrote $out ($((Get-Item $out).Length) bytes)"

    Write-Host 'cc-tts-test: playing…'
    $play = Join-Path $env:USERPROFILE '.claude\hooks\cc-tts-play.ps1'
    & $play -MediaPath $out
    Write-Host 'cc-tts-test: done.'
} finally {
    Remove-Item $out -ErrorAction SilentlyContinue
}

# cursor-tts.ps1 — Cursor Agent stop hook → local Kokoro TTS (same tts.json as Claude Code).
$inputJson = ''
try {
    if ([Console]::IsInputRedirected) {
        $inputJson = [Console]::In.ReadToEnd()
    }
} catch {}

$state = 'waiting'
if ($inputJson) {
    try {
        $data = $inputJson | ConvertFrom-Json
        switch ($data.status) {
            'error'   { $state = 'error'; break }
            'aborted' { Write-Output '{}'; return }
            default   { $state = 'waiting' }
        }
        if ($data.workspace_roots -and $data.workspace_roots.Count -gt 0) {
            $env:CURSOR_PROJECT_DIR = $data.workspace_roots[0]
        }
    } catch {}
}

$configPath = Join-Path $env:USERPROFILE '.claude\tts.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Output '{}'
    return
}

try {
    $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Output '{}'
    return
}

if (-not $cfg.enabled) { Write-Output '{}'; return }
if ($cfg.events -notcontains $state) { Write-Output '{}'; return }

$project = if ($env:CURSOR_PROJECT_DIR) {
    Split-Path -Leaf $env:CURSOR_PROJECT_DIR
} elseif ($env:CLAUDE_PROJECT_DIR) {
    Split-Path -Leaf $env:CLAUDE_PROJECT_DIR
} else {
    Split-Path -Leaf $PWD
}

$tpl = $cfg.templates.$state
$text = ($tpl -replace '\{project\}', $project).Trim()
if ($text.Length -gt $cfg.maxChars) { $text = $text.Substring(0, $cfg.maxChars) }

$scriptBlock = {
    param($Text, $ConfigPath, $State)
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $k = $cfg.kokoro
    $ext = if ($k.format) { $k.format } else { 'mp3' }
    $out = Join-Path $env:TEMP ("cc-tts-cursor-{0}.{1}" -f [guid]::NewGuid().ToString('N'), $ext)
    try {
        $body = @{
            model           = 'kokoro'
            input           = $Text
            voice           = $k.voice
            response_format = $k.format
            speed           = [double]$k.speed
        } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri ($k.url.TrimEnd('/') + '/v1/audio/speech') `
            -Method Post -ContentType 'application/json' -Body $body `
            -TimeoutSec $k.timeoutSec -OutFile $out
        $play = Join-Path $env:USERPROFILE '.claude\hooks\cc-tts-play.ps1'
        if (Test-Path $play) { & $play -MediaPath $out }
    } finally {
        Remove-Item $out -ErrorAction SilentlyContinue
    }
}

Start-Process pwsh.exe -ArgumentList @(
    '-NoLogo', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-Command', "& { $($scriptBlock.ToString()) } -Text '$($text -replace "'", "''")' -ConfigPath '$configPath' -State '$state'"
) -WindowStyle Hidden | Out-Null

Write-Output '{}'

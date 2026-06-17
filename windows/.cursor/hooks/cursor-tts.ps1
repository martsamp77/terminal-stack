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

$notify = Join-Path $env:USERPROFILE '.claude\hooks\cc-tts-notify.ps1'
if (-not (Test-Path -LiteralPath $notify)) {
    Write-Output '{}'
    return
}

$args = @(
    '-NoLogo', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', $notify,
    '-State', $state
)
if ($env:CURSOR_PROJECT_DIR) {
    $args += @('-ProjectDir', $env:CURSOR_PROJECT_DIR)
}

Start-Process pwsh.exe -ArgumentList $args -WindowStyle Hidden | Out-Null
Write-Output '{}'

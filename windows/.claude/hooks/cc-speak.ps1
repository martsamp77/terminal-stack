param(
    [Parameter(Mandatory)][ValidateSet('waiting', 'error')][string]$State,
    [string]$OverrideText,
    [switch]$Foreground
)

$configPath = Join-Path $env:USERPROFILE '.claude\tts.json'
if (-not (Test-Path -LiteralPath $configPath)) { return }

try {
    $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch { return }

if (-not $cfg.enabled) { return }
if ($cfg.events -notcontains $State) { return }

$project = if ($env:CLAUDE_PROJECT_DIR) {
    Split-Path -Leaf $env:CLAUDE_PROJECT_DIR
} else {
    Split-Path -Leaf $PWD
}

function Get-SpeakText {
    if ($OverrideText) { return $OverrideText }
    if ($cfg.messageMode -eq 'hook') {
        $stdin = ''
        try {
            if ([Console]::IsInputRedirected) {
                $stdin = [Console]::In.ReadToEnd()
            }
        } catch {}
        $text = ''
        if ($stdin) {
            try {
                $data = $stdin | ConvertFrom-Json
                $found = [System.Collections.Generic.List[string]]::new()
                function Find-Assistant($obj) {
                    if ($null -eq $obj) { return }
                    if ($obj.PSObject.Properties.Name -contains 'role' -or $obj.PSObject.Properties.Name -contains 'type') {
                        $role = $obj.role; if (-not $role) { $role = $obj.type }
                        if ($role -eq 'assistant') {
                            $c = $obj.content; if (-not $c) { $c = $obj.message }
                            if ($c -is [string] -and $c.Trim()) { $found.Add($c.Trim()) }
                            elseif ($c -is [System.Collections.IEnumerable] -and -not ($c -is [string])) {
                                foreach ($p in $c) {
                                    if ($p.type -eq 'text' -and $p.text) { $found.Add([string]$p.text) }
                                }
                            }
                        }
                    }
                    if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
                        foreach ($item in $obj) { Find-Assistant $item }
                    } elseif ($obj.PSObject.Properties) {
                        foreach ($p in $obj.PSObject.Properties) { Find-Assistant $p.Value }
                    }
                }
                Find-Assistant $data
                if ($found.Count) { $text = $found[$found.Count - 1] }
            } catch {}
        }
        if (-not $text) {
            $tpl = $cfg.templates.$State
            $text = $tpl -replace '\{project\}', $project
        }
    } else {
        $tpl = $cfg.templates.$State
        $text = $tpl -replace '\{project\}', $project
    }
    $text = ($text -replace "[\r\n]+", ' ').Trim()
    if ($text.Length -gt $cfg.maxChars) { $text = $text.Substring(0, $cfg.maxChars) }
    return $text
}

$text = Get-SpeakText
if (-not $text) { return }

$cacheDir = Join-Path $env:LOCALAPPDATA 'terminal-stack'
$debounceFile = Join-Path $cacheDir 'cc-tts.last'
$lockFile = Join-Path $cacheDir 'cc-tts.play.lock'
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }

if (-not $Foreground) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if (Test-Path $debounceFile) {
        $last = [int64](Get-Content $debounceFile -ErrorAction SilentlyContinue)
        if (($now - $last) -lt $cfg.debounceSec) { return }
    }
    Set-Content -LiteralPath $debounceFile -Value $now -NoNewline
}

function Invoke-KokoroSynth([string]$Text, [string]$OutPath) {
    $k = $cfg.kokoro
    $body = @{
        model           = 'kokoro'
        input           = $Text
        voice           = $k.voice
        response_format = $k.format
        speed           = [double]$k.speed
    } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri ($k.url.TrimEnd('/') + '/v1/audio/speech') `
        -Method Post -ContentType 'application/json' -Body $body `
        -TimeoutSec $k.timeoutSec -OutFile $OutPath
}

function Invoke-ChatterboxSynth([string]$Text, [string]$OutPath) {
    $c = $cfg.chatterbox
    $exag = [math]::Round(0.25 + [double]$c.energy, 2)
    $body = @{
        input         = $Text
        voice         = $c.voice
        exaggeration  = $exag
        cfg_weight    = [double]$c.cfgWeight
        temperature   = [double]$c.temperature
    } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri ($c.url.TrimEnd('/') + '/v1/audio/speech') `
        -Method Post -ContentType 'application/json' -Body $body `
        -TimeoutSec $c.timeoutSec -OutFile $OutPath
}

function Invoke-EdgeSynth([string]$Text, [string]$OutPath) {
    if (-not $cfg.edge.enabled) { return $false }
    if (-not (Get-Command edge-tts -ErrorAction SilentlyContinue)) { return $false }
    & edge-tts --voice $cfg.edge.voice --text $Text --write-media $OutPath 2>$null
    return (Test-Path -LiteralPath $OutPath)
}

function Invoke-SynthChain([string]$Text, [string]$OutPath) {
    $engine = $cfg.engine
    try {
        switch ($engine) {
            'kokoro'      { Invoke-KokoroSynth $Text $OutPath; return $true }
            'chatterbox'  { Invoke-ChatterboxSynth $Text $OutPath; return $true }
            'auto' {
                try { Invoke-KokoroSynth $Text $OutPath; return $true } catch {}
                Invoke-ChatterboxSynth $Text $OutPath
                return $true
            }
        }
    } catch {}
    return (Invoke-EdgeSynth $Text $OutPath)
}

function Invoke-PlayMedia([string]$Path) {
    $playScript = Join-Path $env:USERPROFILE '.claude\hooks\cc-tts-play.ps1'
    if (-not (Test-Path -LiteralPath $playScript)) {
        $playScript = Join-Path $env:USERPROFILE '.claude\hooks\cc-speak-play.ps1'
    }
    if (Test-Path -LiteralPath $playScript) {
        & $playScript -MediaPath $Path
        return
    }
    if (Get-Command ffplay -ErrorAction SilentlyContinue) {
        & ffplay -nodisp -autoexit -hide_banner -loglevel quiet $Path 2>$null
    }
}

function Add-ClaudePrefix([string]$SpeakText) {
    if (-not $SpeakText) { return $SpeakText }
    if ($SpeakText.StartsWith('Claude. ')) { return $SpeakText }
    $p = "Claude. $SpeakText"
    if ($p.Length -gt $cfg.maxChars) { return $p.Substring(0, $cfg.maxChars) }
    return $p
}

function Start-SpeakWorker([string]$SpeakText) {
    $SpeakText = Add-ClaudePrefix $SpeakText
    $ext = if ($cfg.kokoro.format) { $cfg.kokoro.format } else { 'mp3' }
    $out = Join-Path $env:TEMP ("cc-tts-{0}.{1}" -f [guid]::NewGuid().ToString('N'), $ext)
    try {
        if (-not (Invoke-SynthChain $SpeakText $out)) { return }
        if (-not (Test-Path -LiteralPath $out) -or (Get-Item $out).Length -eq 0) { return }
        $wait = 0
        while ((Test-Path $lockFile) -and ($wait -lt 30)) {
            Start-Sleep -Milliseconds 200
            $wait++
        }
        New-Item -ItemType File -Path $lockFile -Force | Out-Null
        Invoke-PlayMedia $out
    } finally {
        Remove-Item $lockFile -ErrorAction SilentlyContinue
        Remove-Item $out -ErrorAction SilentlyContinue
    }
}

if ($Foreground) {
    Start-SpeakWorker $text
    return
}

$self = $MyInvocation.MyCommand.Path
$args = @(
    '-NoLogo', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', $self,
    '-State', $State,
    '-Foreground'
)
if ($OverrideText) {
    $args += @('-OverrideText', $OverrideText)
} else {
    # Pass resolved text so the child doesn't re-read stdin (already consumed if hook mode).
    $args += @('-OverrideText', $text)
}
Start-Process -FilePath 'pwsh.exe' -ArgumentList $args -WindowStyle Hidden | Out-Null

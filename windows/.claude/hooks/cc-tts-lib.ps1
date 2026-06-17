# cc-tts-lib.ps1 — shared TTS config + speech formatting (dot-sourced).
$script:CcTtsConfigDir = Join-Path $env:USERPROFILE '.claude\tts'
$script:CcTtsConfigBase = Join-Path $script:CcTtsConfigDir 'config.json'
$script:CcTtsConfigLocal = Join-Path $script:CcTtsConfigDir 'local.json'
$script:CcTtsLegacy = Join-Path $env:USERPROFILE '.claude\tts.json'
$script:CcTtsMerged = $null

function Merge-CcTtsHashtable {
    param($Base, $Over)
    if ($Over -isnot [hashtable] -and $Over -isnot [pscustomobject]) { return $Base }
    $out = @{}
    foreach ($k in $Base.Keys) { $out[$k] = $Base[$k] }
    foreach ($prop in $Over.PSObject.Properties) {
        if ($prop.Name.StartsWith('_')) { continue }
        if ($out.ContainsKey($prop.Name) -and $out[$prop.Name] -is [hashtable] -and $prop.Value -is [pscustomobject]) {
            $out[$prop.Name] = Merge-CcTtsHashtable $out[$prop.Name] ($prop.Value | ConvertTo-Hashtable)
        } else {
            $out[$prop.Name] = $prop.Value
        }
    }
    return $out
}

function ConvertTo-Hashtable {
    param($Obj)
    if ($null -eq $Obj) { return @{} }
    if ($Obj -is [hashtable]) { return $Obj }
    $h = @{}
    foreach ($p in $Obj.PSObject.Properties) {
        if ($p.Value -is [pscustomobject]) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
        else { $h[$p.Name] = $p.Value }
    }
    return $h
}

function Initialize-CcTtsConfig {
    if ($script:CcTtsMerged) { return $script:CcTtsMerged }

    if (-not (Test-Path -LiteralPath $script:CcTtsConfigDir)) {
        New-Item -ItemType Directory -Path $script:CcTtsConfigDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $script:CcTtsConfigBase) -and (Test-Path -LiteralPath $script:CcTtsLegacy)) {
        Copy-Item -LiteralPath $script:CcTtsLegacy -Destination $script:CcTtsConfigBase -Force
    }
    if (-not (Test-Path -LiteralPath $script:CcTtsConfigBase)) {
        if (Test-Path -LiteralPath $script:CcTtsLegacy) {
            $script:CcTtsMerged = Get-Content -LiteralPath $script:CcTtsLegacy -Raw | ConvertFrom-Json
            return $script:CcTtsMerged
        }
        return $null
    }

    $cfg = Get-Content -LiteralPath $script:CcTtsConfigBase -Raw | ConvertFrom-Json
    if (Test-Path -LiteralPath $script:CcTtsConfigLocal) {
        $loc = Get-Content -LiteralPath $script:CcTtsConfigLocal -Raw | ConvertFrom-Json
        $cfgHash = ConvertTo-Hashtable $cfg
        $locHash = ConvertTo-Hashtable $loc
        $merged = Merge-CcTtsHashtable $cfgHash $locHash
        $cfg = $merged | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    }
    if ($cfg.templates -and -not $cfg.announce) {
        $cfg | Add-Member -NotePropertyName announce -NotePropertyValue ([pscustomobject]@{
            includeProject = $true
            messageMode = if ($cfg.messageMode) { $cfg.messageMode } else { 'template' }
            templates = $cfg.templates
        }) -Force
    }
    $script:CcTtsMerged = $cfg
    return $cfg
}

function Get-CcTtsConfigValue {
    param([string]$Path, $Default = $null)
    $cfg = Initialize-CcTtsConfig
    if (-not $cfg) { return $Default }
    $cur = $cfg
    foreach ($part in $Path.Trim('.').Split('.')) {
        if ($null -eq $cur) { return $Default }
        $cur = $cur.$part
    }
    if ($null -eq $cur) { return $Default }
    return $cur
}

function Test-CcTtsEventEnabled {
    param([string]$Event)
    $events = Get-CcTtsConfigValue 'events' @('waiting', 'error')
    if ($events -is [string]) { $events = $events.Split(',') | ForEach-Object { $_.Trim() } }
    return ($events -contains $Event)
}

function Get-CcTtsEffectiveExcitement {
    $e = Get-CcTtsConfigValue 'excitement' $null
    if ($null -ne $e) { return [double]$e }
    return [double](Get-CcTtsConfigValue 'chatterbox.energy' 0.25)
}

function Get-CcTtsEffectiveKokoroSpeed {
    $exc = Get-CcTtsConfigValue 'excitement' $null
    if ($null -ne $exc) { return [math]::Round(0.8 + [double]$exc * 0.4, 2) }
    return [double](Get-CcTtsConfigValue 'kokoro.speed' 1.0)
}

function Build-CcTtsSpeech {
    param(
        [string]$Source = 'claude',
        [string]$State = 'waiting',
        [string]$Project = '',
        [string]$OverrideText = ''
    )
    $cfg = Initialize-CcTtsConfig
    if (-not $cfg) { return '' }

    $maxChars = [int](Get-CcTtsConfigValue 'maxChars' 120)
    $includeProject = Get-CcTtsConfigValue 'announce.includeProject' $true
    if (-not $includeProject) { $Project = '' }

    $text = $OverrideText
    if (-not $text) {
        $tpl = Get-CcTtsConfigValue "announce.templates.$State" ''
        if (-not $tpl) { $tpl = Get-CcTtsConfigValue "templates.$State" '' }
        $text = ($tpl -replace '\{project\}', $Project)
    }
    $text = ($text -replace "[\r\n]+", ' ').Trim()

    if ($Source -ne 'test') {
        $prefixEnabled = Get-CcTtsConfigValue "sources.$Source.prefixEnabled" $true
        $prefix = Get-CcTtsConfigValue "sources.$Source.prefix" $Source
        if ($prefixEnabled -and $prefix -and -not $text.StartsWith("$prefix.")) {
            $text = "$prefix. $text"
        }
    }

    if ($text.Length -gt $maxChars) { $text = $text.Substring(0, $maxChars) }
    return $text
}

function Invoke-CcTtsSynth {
    param([string]$Text, [string]$OutPath)
    $cfg = Initialize-CcTtsConfig
    if (-not $cfg) { return $false }
    $engine = Get-CcTtsConfigValue 'engine' 'kokoro'
    try {
        switch ($engine) {
            'kokoro' {
                $k = $cfg.kokoro
                $body = @{
                    model = 'kokoro'; input = $Text; voice = $k.voice
                    response_format = $k.format; speed = [double](Get-CcTtsEffectiveKokoroSpeed)
                } | ConvertTo-Json -Compress
                Invoke-RestMethod -Uri ($k.url.TrimEnd('/') + '/v1/audio/speech') `
                    -Method Post -ContentType 'application/json' -Body $body `
                    -TimeoutSec $k.timeoutSec -OutFile $OutPath
                return $true
            }
            'chatterbox' {
                $c = $cfg.chatterbox
                $exag = [math]::Round(0.25 + [double](Get-CcTtsEffectiveExcitement), 2)
                $body = @{
                    input = $Text; voice = $c.voice; exaggeration = $exag
                    cfg_weight = [double]$c.cfgWeight; temperature = [double]$c.temperature
                } | ConvertTo-Json -Compress
                Invoke-RestMethod -Uri ($c.url.TrimEnd('/') + '/v1/audio/speech') `
                    -Method Post -ContentType 'application/json' -Body $body `
                    -TimeoutSec $c.timeoutSec -OutFile $OutPath
                return $true
            }
            'auto' {
                try {
                    $k = $cfg.kokoro
                    $body = @{
                        model = 'kokoro'; input = $Text; voice = $k.voice
                        response_format = $k.format; speed = [double](Get-CcTtsEffectiveKokoroSpeed)
                    } | ConvertTo-Json -Compress
                    Invoke-RestMethod -Uri ($k.url.TrimEnd('/') + '/v1/audio/speech') `
                        -Method Post -ContentType 'application/json' -Body $body `
                        -TimeoutSec $k.timeoutSec -OutFile $OutPath
                    return $true
                } catch {
                    $c = $cfg.chatterbox
                    $exag = [math]::Round(0.25 + [double](Get-CcTtsEffectiveExcitement), 2)
                    $body = @{
                        input = $Text; voice = $c.voice; exaggeration = $exag
                        cfg_weight = [double]$c.cfgWeight; temperature = [double]$c.temperature
                    } | ConvertTo-Json -Compress
                    Invoke-RestMethod -Uri ($c.url.TrimEnd('/') + '/v1/audio/speech') `
                        -Method Post -ContentType 'application/json' -Body $body `
                        -TimeoutSec $c.timeoutSec -OutFile $OutPath
                    return $true
                }
            }
        }
    } catch {}
    if (Get-CcTtsConfigValue 'edge.enabled' $true) {
        $voice = Get-CcTtsConfigValue 'edge.voice' 'en-US-AndrewMultilingualNeural'
        if (Get-Command edge-tts -ErrorAction SilentlyContinue) {
            & edge-tts --voice $voice --text $Text --write-media $OutPath 2>$null
            return (Test-Path -LiteralPath $OutPath)
        }
    }
    return $false
}

function Parse-CcTtsInputHook {
    param([string]$InputJson, [string]$Event)
    $state = 'question'
    $override = ''
    if (-not $InputJson) { return @{ State = $state; Override = $override } }
    try {
        $data = $InputJson | ConvertFrom-Json
        switch ($Event) {
            'permission' {
                $state = 'permission'
                if ($data.tool_name) { $override = [string]$data.tool_name }
                elseif ($data.message) { $override = [string]$data.message }
            }
            'notification' {
                $state = 'question'
                if ($data.message) { $override = [string]$data.message }
            }
            'cursor_question' {
                $state = 'question'
                $q = $data.tool_input
                if ($q.questions -and $q.questions.Count -gt 0) {
                    $first = $q.questions[0]
                    if ($first.prompt) { $override = [string]$first.prompt }
                    elseif ($first.question) { $override = [string]$first.question }
                    elseif ($first.header) { $override = [string]$first.header }
                }
            }
            default {
                if ($data.tool_input.questions -and $data.tool_input.questions.Count -gt 0) {
                    $first = $data.tool_input.questions[0]
                    if ($first.question) { $override = [string]$first.question }
                }
            }
        }
    } catch {}
    return @{ State = $state; Override = $override }
}

$env:_ZO_ECHO = '1'
$env:_ZO_EXCLUDE_DIRS = 'C:\Windows\*;*\node_modules\*;*\.git\*;*\target\*;*\dist\*;*\build\*'

function zoxide-prune {
  zoxide query -l | Where-Object { -not (Test-Path $_) } | ForEach-Object { zoxide remove $_ }
}

function ws { Set-Location C:\DATA\Workspace }
function wsp { Set-Location C:\DATA\Workspace_Personal }
function wspu { Set-Location C:\DATA\Workspace_Public }
function wscalibra { Set-Location C:\DATA\Workspace\md-validator }
function wsnetsuite { Set-Location C:\DATA\Workspace\netsuite-customizations }

function cc { claude @args }
function ccc { claude --continue @args }
function ccd { claude --dangerously-skip-permissions @args }
function ccdc { claude --dangerously-skip-permissions --continue @args }
function cca { claude agents }

# ---- starship-stack-start ----
Invoke-Expression (&starship init powershell)
if (Get-Command Enable-TransientPrompt -ErrorAction SilentlyContinue) { Enable-TransientPrompt }

function Invoke-Starship-PreCommand {
    $loc = $executionContext.SessionState.Path.CurrentLocation
    if ($loc.Provider.Name -eq 'FileSystem') {
        Write-Host -NoNewline "`e]7;file://localhost/$($loc.Path)`a"
    }
}
# ---- starship-stack-end ----

# ---- cli-tools-start ----
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
# ---- cli-tools-end ----

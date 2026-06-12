param([Parameter(Mandatory)][ValidateSet('thinking','working','waiting','error')][string]$State)
if (-not $env:WEZTERM_PANE) { return }
$glyph = @{ thinking = '⏳'; working = '⚙'; waiting = '✓'; error = '✗' }[$State]
$project = if ($env:CLAUDE_PROJECT_DIR) {
    Split-Path -Leaf $env:CLAUDE_PROJECT_DIR
} else {
    Split-Path -Leaf $PWD
}
& wezterm.exe cli set-tab-title "cc $glyph $project" 2>$null

# Toast notification — fires for 'waiting' (done) and 'error' if the sentinel file exists.
# Toggle: ccnotify on / ccnotify off
if ($State -in 'waiting', 'error') {
    $toastFile = Join-Path $env:USERPROFILE '.claude\.toast-notify'
    if (Test-Path $toastFile) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $icon = New-Object System.Windows.Forms.NotifyIcon
            $icon.Icon = [System.Drawing.SystemIcons]::Application
            $icon.BalloonTipTitle = 'Claude Code'
            $icon.BalloonTipText = if ($State -eq 'error') { "Error: $project" } else { "Done: $project" }
            $icon.BalloonTipIcon = if ($State -eq 'error') { 'Error' } else { 'Info' }
            $icon.Visible = $true
            $icon.ShowBalloonTip(6000)
            Start-Sleep -Milliseconds 500
            $icon.Dispose()
        } catch {}
    }
}

param([Parameter(Mandatory)][ValidateSet('thinking','waiting','error')][string]$State)
if (-not $env:WEZTERM_PANE) { return }
$glyph = @{ thinking = '⏳'; waiting = '✓'; error = '✗' }[$State]
$project = if ($env:CLAUDE_PROJECT_DIR) {
    Split-Path -Leaf $env:CLAUDE_PROJECT_DIR
} else {
    Split-Path -Leaf $PWD
}
& wezterm.exe cli set-tab-title "cc $glyph $project" 2>$null

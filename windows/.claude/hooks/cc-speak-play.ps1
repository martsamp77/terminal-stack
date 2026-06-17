# cc-speak-play.ps1 — backward-compatible alias for cc-tts-play.ps1
param([Parameter(Mandatory)][string]$MediaPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here 'cc-tts-play.ps1') -MediaPath $MediaPath

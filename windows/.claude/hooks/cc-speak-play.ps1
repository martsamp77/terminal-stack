param(
    [Parameter(Mandatory)][string]$MediaPath
)

if (-not (Test-Path -LiteralPath $MediaPath)) {
    Write-Error "Media file not found: $MediaPath"
    exit 1
}

if (Get-Command ffplay -ErrorAction SilentlyContinue) {
    & ffplay -nodisp -autoexit -hide_banner -loglevel quiet $MediaPath 2>$null
    exit $LASTEXITCODE
}

# Fallback: Windows Media Player COM (handles mp3/wav).
try {
    $wmp = New-Object -ComObject WMPlayer.OCX
    $wmp.settings.volume = 100
    $wmp.URL = (Resolve-Path -LiteralPath $MediaPath).Path
    while ($wmp.playState -ne 1 -and $wmp.playState -ne 0) {
        Start-Sleep -Milliseconds 150
    }
    $wmp.close()
    exit 0
} catch {}

Write-Error 'No audio player found. Install ffplay: winget install Gyan.FFmpeg'
exit 1

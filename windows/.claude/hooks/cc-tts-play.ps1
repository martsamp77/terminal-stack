param(
    [Parameter(Mandatory)][string]$MediaPath
)

if (-not (Test-Path -LiteralPath $MediaPath)) {
    Write-Error "Media file not found: $MediaPath"
    exit 1
}

$resolved = (Resolve-Path -LiteralPath $MediaPath).Path

if (Get-Command ffplay -ErrorAction SilentlyContinue) {
    & ffplay -nodisp -autoexit -hide_banner -loglevel quiet $resolved 2>$null
    exit $LASTEXITCODE
}

try {
    $wmp = New-Object -ComObject WMPlayer.OCX
    $wmp.settings.volume = 100
    $wmp.URL = $resolved
    $wmp.controls.play() | Out-Null
    Start-Sleep -Milliseconds 300
    $deadline = (Get-Date).AddSeconds(90)
    while ($wmp.playState -notin 0, 1, 8 -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
    }
    $wmp.close()
    exit 0
} catch {
    Write-Error $_
}

Write-Error 'No audio player. Install ffplay: winget install Gyan.FFmpeg'
exit 1

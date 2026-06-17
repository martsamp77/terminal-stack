param(
    [Parameter(Mandatory)][string]$MediaPath
)

if (-not (Test-Path -LiteralPath $MediaPath)) {
    Write-Error "Media file not found: $MediaPath"
    exit 1
}

$resolved = (Resolve-Path -LiteralPath $MediaPath).Path

function Find-FfplayPath {
    if (Get-Command ffplay -ErrorAction SilentlyContinue) {
        return (Get-Command ffplay).Source
    }
    $link = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\ffplay.exe'
    if (Test-Path -LiteralPath $link) { return $link }
    $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $pkgRoot) {
        $hit = Get-ChildItem -LiteralPath $pkgRoot -Filter 'ffplay.exe' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($hit) { return $hit }
    }
    return $null
}

$ffplay = Find-FfplayPath
if ($ffplay) {
    & $ffplay -nodisp -autoexit -hide_banner -loglevel quiet $resolved 2>$null
    exit $LASTEXITCODE
}

Write-Error 'ffplay not found. Install: winget install Gyan.FFmpeg (then restart WSL if calling from WSL)'
exit 1

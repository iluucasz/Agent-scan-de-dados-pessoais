$ErrorActionPreference = 'Stop'

$svgPath = Join-Path $PSScriptRoot '..\assets\icons\privacy-pulse.svg'
$outPath = Join-Path $PSScriptRoot '..\assets\icons\privacy-pulse-icon.png'

$svg = Get-Content $svgPath -Raw

# Extract embedded PNG (data:image/png;base64,...) from the SVG.
$match = [regex]::Match($svg, 'data:image/png;base64,([^"\s]+)')
if (-not $match.Success) {
  throw "Base64 PNG not found inside SVG: $svgPath"
}

[IO.File]::WriteAllBytes($outPath, [Convert]::FromBase64String($match.Groups[1].Value))
Write-Host "Wrote $outPath"

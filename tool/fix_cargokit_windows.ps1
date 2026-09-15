# Repair cargokit's hidden-directory lookup in the resolved local Pub cache.
# Idempotent; only the known upstream line is changed. No build or app restart.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $project '.dart_tool/package_config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$package = $config.packages | Where-Object { $_.name -eq 'super_native_extensions' }
if ($null -eq $package) {
    throw 'super_native_extensions is not resolved. Run flutter pub get first.'
}

$configUri = [Uri]::new($configPath)
$packageUri = [Uri]::new($configUri, [string] $package.rootUri)
$scriptPath = Join-Path $packageUri.LocalPath 'cargokit/cmake/resolve_symlinks.ps1'
$source = [IO.File]::ReadAllText($scriptPath)
$before = '$item = Get-Item $realPath'
$after = '$item = Get-Item -LiteralPath $realPath -Force -ErrorAction Stop'

if ($source.Contains($after)) {
    Write-Output 'Cargokit hidden-directory fix is already applied.'
    return
}
if (-not $source.Contains($before)) {
    throw 'The upstream script has changed. Review it before applying this fix.'
}

[IO.File]::WriteAllText(
    $scriptPath,
    $source.Replace($before, $after),
    [Text.UTF8Encoding]::new($false)
)
Write-Output 'Fixed cargokit Get-Item for hidden directories and literal paths.'

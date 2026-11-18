#requires -Version 7.0
param([Alias('h')][switch]$Help, [string]$Architecture)
$ErrorActionPreference = 'Stop'
if ($Help) { Write-Host 'build.ps1 [-Architecture macos-universal]'; return }
. "$PSScriptRoot/scriptHelper.ps1"
Write-Host "=== building $projectName... ==="
Set-Location -LiteralPath $repoRoot
checkVerBuild $Architecture
$targetArchitecture = getArchitecture @($Architecture)
$targets = getBuildTargets $targetArchitecture
if (-not (Test-Path -LiteralPath $iconPng)) { throw "Missing source icon: $iconPng" }
New-Item -ItemType Directory -Path $publishFolder -Force | Out-Null
foreach ($target in $targets) {
    $swiftArgs = @('build', '-c', 'release') + @($target.SwiftArchs | ForEach-Object { '--arch', $_ }) + @('-Xswiftc', '-warnings-as-errors')
    runNativeCommand swift $swiftArgs "swift build $($target.Architecture)"
    assembleApp -BinFolder (getSwiftBinPath $swiftArgs) -AppPath $target.AppPath
    runNativeCommand codesign @('--force', '--sign', '-', $target.AppPath) "codesign $($target.Architecture)"
    $zip = "$publishFolder/$(buildAssetName $target.Architecture)"
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    runNativeCommand ditto @('-c', '-k', '--sequesterRsrc', '--keepParent', $target.AppPath, $zip) "ditto $($target.Architecture)"
}
closeOut 0

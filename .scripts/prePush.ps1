#requires -Version 7.0
param([Alias('h')][switch]$Help, [Parameter(ValueFromRemainingArguments = $true)][string[]]$BuildArgs)
$ErrorActionPreference = 'Stop'
if ($Help) { Write-Host 'prePush.ps1 [-universal]'; return }
. "$PSScriptRoot/scriptHelper.ps1"
Set-Location -LiteralPath $repoRoot
$architecture = getArchitecture (@($BuildArgs) + @($args))
if ($architecture -eq 'help') { Write-Host 'prePush.ps1 [-universal]'; return }
runNativeCommand swift @('test') 'swift test'
buildAll $architecture
Write-Host 'Pre-push tests, build, and packaging passed. No commit or push was performed.'
closeOut 0

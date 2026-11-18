#requires -Version 7.0
param([Alias('h')][switch]$Help, [Alias('n')][switch]$DryRun)
$ErrorActionPreference = 'Stop'
if ($Help) { Write-Host 'pushRelease.ps1 [-DryRun]'; return }
. "$PSScriptRoot/scriptHelper.ps1"
Set-Location -LiteralPath $repoRoot
# Ship exactly this version's zips: a stale or extra file means prePush did not run for this version.
$expected = @($buildTargets | ForEach-Object { buildAssetName $_.Architecture })
$found = @(Get-ChildItem -LiteralPath $publishFolder -File -ErrorAction SilentlyContinue | ForEach-Object Name)
$missing = @($expected | Where-Object { $_ -notin $found })
$extra = @($found | Where-Object { $_ -notin $expected })
if ($missing -or $extra) {
    throw "publish/ does not match v${versionContents} (missing: $($missing -join ', '); " +
        "extra: $($extra -join ', ')). Run prePush.ps1."
}
$assetArgs = @($expected | ForEach-Object { "$publishFolder/$_" })

$notes = readBuildNotes
$releaseTitle = $notes.Title ? $notes.Title : $tag
$releaseArgs = @('release', 'create', $tag, '--title', $releaseTitle, '--repo', $ghRepo)
if ($notes.Body) { $releaseArgs += @('--notes', $notes.Body) } else { $releaseArgs += '--generate-notes' }
$releaseUrl = "$appURL/releases/tag/$tag"

# Check before the tag moves: `gh release create` cannot replace an existing release.
$view = & gh release view $tag --repo $ghRepo --json tagName 2>&1
if ($LASTEXITCODE -eq 0) { throw "Release $tag already exists. Delete it on GitHub or bump the version first." }
if ("$view" -notmatch 'release not found') { throw "gh release view failed: $view" }

if ($DryRun) {
    Write-Host "Dry run: git tag -f $tag"
    Write-Host "Dry run: git push origin refs/tags/$tag --force"
    Write-Host "Dry run: gh $((($releaseArgs + $assetArgs) -join ' '))"
    Write-Host "Dry run: open $releaseUrl"
    return
}
runNativeCommand git @('tag', '-f', $tag) 'git tag'
runNativeCommand git @('push', 'origin', "refs/tags/$tag", '--force') 'git push tag'
runNativeCommand gh ($releaseArgs + $assetArgs) 'gh release create'
openUrl $releaseUrl
closeOut 0

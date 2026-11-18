#requires -Version 7.0
param(
    [Alias('h')][switch]$Help,
    [Alias('f')][switch]$Force,
    [Alias('n')][switch]$DryRun,
    [Parameter(Position = 0)][string]$Message
)
$ErrorActionPreference = 'Stop'
if ($Help) { Write-Host 'push.ps1 [-Force] [-DryRun] ["commit message"]'; return }
. "$PSScriptRoot/scriptHelper.ps1"
Set-Location -LiteralPath $repoRoot
# A passed message wins. buildNotes.txt counts only when changed since the last commit;
# unchanged, it still holds the previous push's message.
$subject = $Message.Trim()
$body = ''
if (-not $subject -and (buildNotesChanged)) {
    $notes = readBuildNotes
    $subject = $notes.Title
    $body = $notes.Body
}
if (-not $subject -and -not $DryRun) { $subject = (Read-Host 'Commit message').Trim() }
if (-not $subject) { throw 'Provide a commit message, or write a new one to buildNotes.txt (it is unchanged since the last commit).' }
$branch = ((& git branch --show-current) | Out-String).Trim()
if ($LASTEXITCODE) { throw 'Could not determine the current branch.' }
if (-not $branch) { throw 'Detached HEAD; refusing to push.' }
$commitArgs = @('commit', '-m', $subject)
if ($body) { $commitArgs += @('-m', $body) }
$pushArgs = @('push', 'origin', $branch); if ($Force) { $pushArgs += '--force' }
if ($DryRun) {
    Write-Host "Dry run: git add -A"
    Write-Host "Dry run: git $($commitArgs -join ' ')"
    Write-Host "Dry run: git $($pushArgs -join ' ')"
    Write-Host "Dry run: open $appURL"
    return
}
runNativeCommand git @('add', '-A') 'git add'
runNativeCommand git $commitArgs 'git commit'
runNativeCommand git $pushArgs 'git push'
openUrl $appURL
closeOut 0

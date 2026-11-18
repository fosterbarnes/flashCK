#requires -Version 7.0
# Non-interactive push for the agent-push skill: -Context prints what the agent needs to write
# buildNotes.txt; the default mode validates it, runs prePush.ps1 and push.ps1 quietly, then reports.
param([Alias('h')][switch]$Help, [switch]$Context)
$ErrorActionPreference = 'Stop'
if ($Help) { Write-Host 'agentPush.ps1 [-Context]'; return }
. "$PSScriptRoot/scriptHelper.ps1"
Set-Location -LiteralPath $repoRoot
$notesChanged = buildNotesChanged

if ($Context) {
    # buildNotes.md is git-ignored: list entry headings dated after the last commit (all without one).
    $since = & git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M' 2>$null
    if ($LASTEXITCODE) { $since = '' }
    Write-Host "branch: $(git branch --show-current)  tag: $tag"
    Write-Host '--- status'
    git status --short
    Write-Host '--- buildNotes.md entries since the last commit'
    if (Test-Path -LiteralPath "$repoRoot/buildNotes.md") {
        Select-String -LiteralPath "$repoRoot/buildNotes.md" -Pattern '^## (\d{4}-\d\d-\d\d) \(~(\d\d:\d\d)\)' |
            Where-Object { "$($_.Matches[0].Groups[1].Value) $($_.Matches[0].Groups[2].Value)" -gt $since } |
            ForEach-Object Line
    }
    if ($since) {
        Write-Host '--- last 10 subjects'
        git log -10 --format=%s
        Write-Host '--- last commit message (style sample)'
        git log -1 --format=%B
    } else {
        Write-Host '--- (no commits yet)'
    }
    if ($notesChanged) { Write-Host 'WARN: buildNotes.txt already holds a new message; overwrite it.' }
    return
}

# Fail on a bad message before the slow checks run.
if (-not $notesChanged) { throw 'buildNotes.txt is missing or still holds the last commit subject; write the new message first.' }
$notes = readBuildNotes
if (-not $notes.Title -or -not $notes.Body) { throw 'buildNotes.txt needs line 1, one blank line, then a non-empty body.' }

# Run each script in-process as one pipeline so closeOut stays a no-op; print the tail only on failure.
$previousPipeline = $env:BASE_BUILD_PIPELINE
try {
    $env:BASE_BUILD_PIPELINE = '1'
    foreach ($step in 'prePush', 'push') {
        $log = [Collections.Generic.List[string]]::new()
        try { & "$PSScriptRoot/$step.ps1" *>&1 | ForEach-Object { $log.Add("$_") } }
        catch {
            $log | Select-Object -Last 40
            throw "$step.ps1 failed: $_"
        }
        Write-Host "$step.ps1 passed."
    }
} finally {
    $env:BASE_BUILD_PIPELINE = $previousPipeline
}

Set-Location -LiteralPath $repoRoot
Write-Host "--- pushed $(git log -1 --format=%h) to origin/$(git branch --show-current)"
git show -s --format=%B HEAD
git show --name-status --format= HEAD

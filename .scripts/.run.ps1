#requires -Version 7.0
param([Alias('h')][switch]$Help, [Parameter(ValueFromRemainingArguments = $true)][string[]]$AppLaunchArgs)
$ErrorActionPreference = 'Stop'
if ($Help) { Write-Host '.run.ps1 [-- app args...]'; return }
. "$PSScriptRoot/scriptHelper.ps1"
Set-Location -LiteralPath $repoRoot
if (@($AppLaunchArgs | Where-Object { "$_" -match '(?i)^(--help|-h)$' })) { Write-Host '.run.ps1 [-- app args...]'; return }
$forward = @($AppLaunchArgs)
$swiftArgs = @('build', '-c', 'debug')
$runExe = "$runApp/Contents/MacOS/$projectName"
try {
    while ($true) {
        # A dev build left running by a closed terminal would write the same library.json.
        $running = @(Get-Process -Name $projectName -ErrorAction SilentlyContinue | Where-Object Path -eq $runExe)
        if ($running) {
            $running | Stop-Process -Force
            $running | Wait-Process
        }
        setVerBuild "macos-$([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant())"
        runNativeCommand swift $swiftArgs 'swift build'
        assembleApp -BinFolder (getSwiftBinPath $swiftArgs) -AppPath $runApp
        $startArgs = @{ FilePath = $runExe; WorkingDirectory = $repoRoot; NoNewWindow = $true; PassThru = $true }
        if ($forward) { $startArgs.ArgumentList = $forward }
        $proc = Start-Process @startArgs
        # Started by its executable, the app opens behind the terminal. Once it has checked in with
        # LaunchServices, `open -a` brings that same instance forward; before that it starts a second one.
        for ($i = 0; $i -lt 100 -and -not $proc.HasExited; $i++) {
            if (lsappinfo find "pid=$($proc.Id)") { runNativeCommand open @('-a', $runApp) 'open'; break }
            Start-Sleep -Milliseconds 50
        }
        Write-Host "=== running $projectName... === `nq = quit `nr , up arrow = restart"
        $action = $null
        while (-not $proc.HasExited) {
            Start-Sleep -Milliseconds 50
            try { if (-not [Console]::KeyAvailable) { continue } } catch { continue }
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::R -or $key.Key -eq [ConsoleKey]::UpArrow) { $action = 'restart'; break }
            if ($key.Key -eq [ConsoleKey]::Q) { $action = 'quit'; break }
        }
        if ($action) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
        if ($action -ne 'restart') {
            if (-not $action -and $proc.ExitCode -ne 0) { throw "$projectName exited with code $($proc.ExitCode)." }
            if ($action -eq 'quit') { Get-Process -Name $projectName -ErrorAction SilentlyContinue | Where-Object Path -eq $runExe | Stop-Process -Force }
            break
        }
    }
}
catch {
    closeOut -KeepOpen
    throw
}
closeOut 0

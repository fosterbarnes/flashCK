#requires -Version 7.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$projectName = 'flashCK'
$projectAppName = "$projectName.app"
$srcRoot = "$repoRoot/src"
$bundlePlist = "$srcRoot/bundle/Info.plist"
$versionFolder = "$repoRoot/.version"
$version = "$versionFolder/version"
$versionBuild = "$versionFolder/versionBuild"
$versionTag = "$versionFolder/versionTag"
$buildNotes = "$repoRoot/buildNotes.txt"
$readme = "$repoRoot/README.md"
$buildFolder = "$repoRoot/.build"
$iconsetFolder = "$buildFolder/$projectName.iconset"
$runApp = "$buildFolder/run/$projectAppName"
$publishFolder = "$repoRoot/publish"
$iconDir = "$repoRoot/.res/ico"
$iconPng = "$iconDir/icon.png"
$appPublisher = 'fosterbarnes'
$appURL = "https://github.com/$appPublisher/$projectName"
$ghRepo = "$appPublisher/$projectName"
# .version/version: line 1 semver, line 2 optional release tag, line 3 optional build number.
$versionLines = @(([IO.File]::ReadAllText($version) -split '\r?\n') | ForEach-Object { $_.Trim() }) + @('', '')
$versionContents = $versionLines[0]
# Release tag: .version/versionTag, else line 2, else v<semver>.
$versionTagContents = if (Test-Path -LiteralPath $versionTag) { ([IO.File]::ReadAllText($versionTag)).Trim() } else { '' }
$tag = @($versionTagContents, $versionLines[1], "v$versionContents") | Where-Object { $_ } | Select-Object -First 1
# CFBundleVersion: line 3, else the semver.
$bundleBuild = @($versionLines[2], $versionContents) | Where-Object { $_ } | Select-Object -First 1
$icnsSizes = @(16, 32, 128, 256, 512)
# README download buttons are shared SVGs in fosterbarnes/res/btn; both Mac buttons link the same universal zip.
$buttonURL = 'https://raw.githubusercontent.com/fosterbarnes/res/main/btn'
$buildTargets = @(
    @{ Architecture = 'macos-universal'; SwiftArchs = @('arm64', 'x86_64'); AppPath = "$publishFolder/$projectAppName"; Buttons = @(@{ File = 'appleIntel.svg'; Label = 'macOS Intel' }, @{ File = 'appleArm.svg'; Label = 'macOS Apple Silicon' }) }
)
$noBom = New-Object System.Text.UTF8Encoding $false
$weztermExe = (Get-Command wezterm -ErrorAction SilentlyContinue)?.Source
if (-not $weztermExe -and (Test-Path -LiteralPath '/Applications/WezTerm.app/Contents/MacOS/wezterm')) { $weztermExe = '/Applications/WezTerm.app/Contents/MacOS/wezterm' }

function readVerFile {
    param([string]$LiteralPath = $version)
    $lines = @(([IO.File]::ReadAllText($LiteralPath) -split '\r?\n' | ForEach-Object { $_.Trim() }))
    while ($lines.Count -lt 3) { $lines += '' }
    $lines
}

function writeFileNoBom {
    param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][string]$Content)
    [IO.File]::WriteAllText($LiteralPath, $Content, $noBom)
}

function writeVerFile {
    param(
        [Parameter(Mandatory)][string]$SemVer,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Tag,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Build
    )
    writeFileNoBom -LiteralPath $version -Content (($SemVer.Trim(), $Tag.Trim(), $Build.Trim()) -join "`n")
}

function setVerBuild {
    param([Parameter(Mandatory)][string]$Platform)
    writeFileNoBom -LiteralPath $versionBuild -Content ($Platform.Trim() + "`n")
}

function checkVerBuild {
    param([string]$Architecture)
    if (Test-Path -LiteralPath $versionBuild) { return }
    setVerBuild ([string]::IsNullOrWhiteSpace($Architecture) ? 'macos-universal' : $Architecture)
}

function getArchitecture {
    param([string[]]$FlagArgs)
    $found = @()
    foreach ($arg in @($FlagArgs)) {
        if ([string]::IsNullOrWhiteSpace("$arg")) { continue }
        switch -Regex ("$arg".Trim()) {
            '(?i)^(macos-universal|--macos-universal|-macos-universal|universal|--universal|-universal)$' { $found += 'macos-universal' }
            '(?i)^(--help|-h)$' { return 'help' }
            default { throw "Unknown architecture flag: $arg" }
        }
    }
    $unique = @($found | Select-Object -Unique)
    if ($unique.Count -gt 1) { throw "Conflicting architecture flags: $($unique -join ', ')" }
    if ($unique.Count -eq 1) { return $unique[0] }
    $null
}

function getBuildTargets {
    param([string]$Architecture)
    if (-not $Architecture) { return $buildTargets }
    $target = @($buildTargets | Where-Object Architecture -eq $Architecture)
    if (-not $target) { throw "No build target for architecture: $Architecture" }
    return ,$target[0]
}

function deleteDir {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    if (Test-Path -LiteralPath $Path) { throw "Could not remove '$Path'." }
}

function runNativeCommand {
    param([Parameter(Mandatory)][string]$FilePath, [Parameter(Mandatory)]$ArgumentList, [Parameter(Mandatory)][string]$Name)
    & $FilePath @ArgumentList
    if ($LASTEXITCODE) { throw "$Name failed (exit $LASTEXITCODE)." }
}

function writeClearedLine {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][int]$PadWidth, [switch]$NoNewline)
    Write-Host "`r$Text$(' ' * [Math]::Max(0, $PadWidth - $Text.Length))" -NoNewline:$NoNewline
}

function closeOut {
    param([int]$Seconds = 5, [switch]$KeepOpen)
    if ($KeepOpen) { return }
    if ($env:BASE_BUILD_PIPELINE) { return }
    if ($Seconds -lt 0) { $Seconds = 0 }
    if ($Seconds -gt 0) {
        $pad = "closing after $Seconds seconds..."
        foreach ($n in $Seconds..1) {
            writeClearedLine -Text "closing after $n seconds..." -PadWidth $pad.Length -NoNewline
            Start-Sleep -Seconds 1
        }
        writeClearedLine -Text 'closing...' -PadWidth $pad.Length
    }
    $caller = $MyInvocation.PSCommandPath
    if ([string]::IsNullOrWhiteSpace($caller)) { return }
    $argv = [Environment]::GetCommandLineArgs()
    $fileArg = $null
    for ($i = 0; $i -lt $argv.Length; $i++) {
        if ("$($argv[$i])" -match '^(?i)-File$|^(?i)-f$') {
            if ($i + 1 -lt $argv.Length) { $fileArg = $argv[$i + 1] }
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($fileArg)) { return }
    try {
        $fileFull = [IO.Path]::GetFullPath($fileArg)
        $callerFull = [IO.Path]::GetFullPath($caller)
    } catch { return }
    if (-not [string]::Equals($fileFull, $callerFull, [StringComparison]::OrdinalIgnoreCase)) { return }
    try {
        if ($env:SCRIPT_OWN_PANE -and $env:WEZTERM_PANE -and $weztermExe) { & $weztermExe @('cli', 'kill-pane', '--pane-id', $env:WEZTERM_PANE) }
    } catch { }
    [Environment]::Exit(0)
}

function getSwiftBinPath {
    param([Parameter(Mandatory)][string[]]$BuildArgs)
    $binPath = "$(& swift @BuildArgs '--show-bin-path' | Select-Object -Last 1)".Trim()
    if ($LASTEXITCODE) { throw "swift --show-bin-path failed (exit $LASTEXITCODE)." }
    if (-not $binPath) { throw 'swift --show-bin-path returned no path.' }
    $binPath
}

function makeIcns {
    param([string]$InputPath = $iconPng, [Parameter(Mandatory)][string]$OutputPath)
    if (-not (Test-Path -LiteralPath $InputPath)) { throw "Missing source icon: $InputPath" }
    deleteDir $iconsetFolder
    New-Item -ItemType Directory -Path $iconsetFolder -Force | Out-Null
    foreach ($size in $icnsSizes) {
        foreach ($scale in 1, 2) {
            $pixels = $size * $scale
            $suffix = if ($scale -eq 2) { '@2x' } else { '' }
            $output = "$iconsetFolder/icon_${size}x${size}${suffix}.png"
            runNativeCommand sips @('-z', "$pixels", "$pixels", $InputPath, '--out', $output) "sips resize ($pixels)" | Out-Null
        }
    }
    runNativeCommand iconutil @('-c', 'icns', $iconsetFolder, '-o', $OutputPath) 'iconutil'
}

function assembleApp {
    param([Parameter(Mandatory)][string]$BinFolder, [Parameter(Mandatory)][string]$AppPath)
    $binary = "$BinFolder/$projectName"
    if (-not (Test-Path -LiteralPath $binary)) { throw "Missing build output: $binary" }
    if (-not (Test-Path -LiteralPath $iconPng)) { throw "Missing source icon: $iconPng" }
    deleteDir $AppPath
    $contents = "$AppPath/Contents"
    New-Item -ItemType Directory -Path "$contents/MacOS", "$contents/Resources" -Force | Out-Null
    Copy-Item -LiteralPath $binary -Destination "$contents/MacOS/$projectName" -Force
    Copy-Item -LiteralPath $bundlePlist -Destination "$contents/Info.plist" -Force
    Copy-Item -LiteralPath "$repoRoot/LICENSE", "$repoRoot/THIRD_PARTY_NOTICES.txt" -Destination "$contents/Resources" -Force
    $stamps = [ordered]@{ CFBundleShortVersionString = $versionContents; CFBundleVersion = $bundleBuild }
    foreach ($key in $stamps.Keys) {
        runNativeCommand plutil @('-replace', $key, '-string', $stamps[$key], "$contents/Info.plist") "plutil $key"
    }
    makeIcns -OutputPath "$contents/Resources/$projectName.icns"
}

function openUrl {
    param([Parameter(Mandatory)][string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { throw 'openUrl requires a URL.' }
    runNativeCommand open @($Url) 'open'
}

# buildNotes.txt: line 1 title, one blank line, then the body. Both empty when the file or line 1 is empty.
function readBuildNotes {
    $notes = @{ Title = ''; Body = '' }
    if (-not (Test-Path -LiteralPath $buildNotes)) { return $notes }
    $lines = @([IO.File]::ReadAllLines($buildNotes))
    if ($lines.Count -eq 0 -or -not $lines[0].Trim()) { return $notes }
    if ($lines.Count -ge 2 -and $lines[1].Trim()) {
        throw 'buildNotes.txt must have one blank line after the first line, then the description.'
    }
    $notes.Title = $lines[0].Trim()
    if ($lines.Count -gt 2) { $notes.Body = ($lines[2..($lines.Count - 1)] -join "`n").Trim() }
    $notes
}

# buildNotes.txt is git-ignored, so it is new when line 1 differs from the last commit subject.
# False when the file or line 1 is empty; true when there are no commits yet.
function buildNotesChanged {
    $title = (readBuildNotes).Title
    if (-not $title) { return $false }
    $head = & git log -1 --format=%s 2>$null
    $LASTEXITCODE -ne 0 -or $title -ne "$head".Trim()
}

function buildAssetName {
    param([Parameter(Mandatory)][string]$Architecture)
    "${projectName}_v${versionContents}_${Architecture}.zip"
}

function buildAll {
    param([string]$Architecture)
    $previousPipeline = $env:BASE_BUILD_PIPELINE
    try {
        $env:BASE_BUILD_PIPELINE = '1'
        deleteDir $publishFolder
        $params = @{}; if ($Architecture) { $params.Architecture = $Architecture }
        runNativeCommand -FilePath "$PSScriptRoot/build.ps1" -ArgumentList $params -Name 'build.ps1'
        runNativeCommand -FilePath "$PSScriptRoot/updateReadme.ps1" -ArgumentList @{} -Name 'updateReadme.ps1'
    } finally {
        $env:BASE_BUILD_PIPELINE = $previousPipeline
    }
}

Set-Location -LiteralPath $repoRoot

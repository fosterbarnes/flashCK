#requires -Version 7.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/scriptHelper.ps1"
Set-Location -LiteralPath $repoRoot
if (-not (Test-Path -LiteralPath $readme)) { throw "README not found: $readme" }
$content = [IO.File]::ReadAllText($readme)
$start = '<!-- Quick Reference -->'
$end = '<!-- End Quick Reference -->'
$startIndex = $content.IndexOf($start, [StringComparison]::Ordinal)
$endIndex = $content.IndexOf($end, [StringComparison]::Ordinal)
if ($startIndex -lt 0 -or $endIndex -lt $startIndex) { throw 'README Quick Reference markers are missing.' }
# One table row per build target, one button cell per button; every button links the target's zip.
$rows = foreach ($target in $buildTargets) {
    $asset = "$appURL/releases/download/$tag/$(buildAssetName $target.Architecture)"
    '<tr>'
    foreach ($button in $target.Buttons) {
        "<td align=`"center`" valign=`"top`"><a href=`"$asset`"><img src=`"$buttonURL/$($button.File)`" width=`"180`" height=`"auto`" alt=`"$($button.Label) ZIP`"/></a></td>"
    }
    '</tr>'
}
$lines = @($start; '<table border="0">'; '<tbody>'; $rows; '</tbody>'; '</table>'; $end)
$prefix = $content.Substring(0, $startIndex) ; $suffix = $content.Substring($endIndex + $end.Length)
writeFileNoBom -LiteralPath $readme -Content ($prefix + ($lines -join "`n") + $suffix)
closeOut 0

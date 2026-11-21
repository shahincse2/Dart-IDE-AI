<#
  The second half of the rename from "DartLab" to "Dart IDE": every remaining
  mention, decided line by line from rename_report.txt.

  From the project root (D:\Ostad\dart_ide):

    powershell -ExecutionPolicy Bypass -File tool\rename_leftovers.ps1          # only looks
    powershell -ExecutionPolicy Bypass -File tool\rename_leftovers.ps1 -Apply   # changes the files

  The rules, in this order (the first that fits a place is applied there):
    dartlab/downloads, dartlab/import     -> dart_ide/downloads, dart_ide/import   (Dart AND Kotlin together)
    'dartlab.xxx'  (saved settings keys)   -> 'dart_ide.xxx'
    dartlabWrite ... (code names)          -> dartIdeWrite ...
    DartLabApp, _DartLabOutput ...         -> DartIdeApp, _DartIdeOutput ...
    'dartlab_run_', 'dartlab_files_test'   -> 'dart_ide_run_', 'dart_ide_files_test'
    Download/DartLab, subfolder 'DartLab'  -> Download/Dart IDE, 'Dart IDE'
    DartLab (the name on its own)          -> Dart IDE

  Scope: lib\, test\ (.dart), android\app\src\ (.kt) and README.md.
#>
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) {
  throw "Run this from the project root (the folder with pubspec.yaml). Now in: $root"
}
$utf8 = New-Object System.Text.UTF8Encoding $false   # UTF-8 without a BOM

$rules = @(
  @('dartlab/downloads', 'dart_ide/downloads'),
  @('dartlab/import', 'dart_ide/import'),
  @("'dartlab\.", "'dart_ide."),
  @('dartlab(?=[A-Z])', 'dartIde'),
  @('DartLab(?=[A-Za-z0-9_])', 'DartIde'),
  @("'dartlab_run_'", "'dart_ide_run_'"),
  @("'dartlab_files_test'", "'dart_ide_files_test'"),
  @('Download(s?)/DartLab', 'Download$1/Dart IDE'),
  @("subfolder = 'DartLab'", "subfolder = 'Dart IDE'"),
  @("\['subfolder'\], 'DartLab'", "['subfolder'], 'Dart IDE'"),
  @('(?<![A-Za-z0-9_])DartLab(?![A-Za-z0-9_])', 'Dart IDE')
)

$files = @()
foreach ($dir in 'lib', 'test') {
  $files += Get-ChildItem -Path (Join-Path $root $dir) -Recurse -File -Filter '*.dart'
}
$kotlinDir = Join-Path $root 'android\app\src'
if (Test-Path $kotlinDir) {
  $files += Get-ChildItem -Path $kotlinDir -Recurse -File -Filter '*.kt'
}
$readme = Join-Path $root 'README.md'
if (Test-Path $readme) { $files += Get-Item $readme }

$changedFiles = 0
$left = @()
$channels = @{ 'dart_ide/downloads' = @{ kt = 0; dart = 0 }; 'dart_ide/import' = @{ kt = 0; dart = 0 } }

foreach ($file in $files) {
  $text = [System.IO.File]::ReadAllText($file.FullName)
  $new = $text
  foreach ($rule in $rules) { $new = [regex]::Replace($new, $rule[0], $rule[1]) }

  if ($new -ne $text) {
    $changedFiles++
    if ($Apply) { [System.IO.File]::WriteAllText($file.FullName, $new, $utf8) }
  }

  $relative = $file.FullName.Substring($root.Length + 1)
  $number = 0
  foreach ($line in ($new -split "`r?`n")) {
    $number++
    if ($line -match '(?i)dartlab') { $left += ('{0}:{1}: {2}' -f $relative, $number, $line.Trim()) }
  }

  $kind = if ($file.Extension -eq '.kt') { 'kt' } elseif ($relative -like 'lib\*') { 'dart' } else { $null }
  if ($kind) {
    foreach ($name in @($channels.Keys)) {
      $channels[$name][$kind] += [regex]::Matches($new, [regex]::Escape($name)).Count
    }
  }
}

$mode = if ($Apply) { 'CHANGED' } else { 'would change (dry run, nothing was written)' }
Write-Host ''
Write-Host "files : $changedFiles $mode"
Write-Host "left  : $($left.Count) lines still mention dartlab"
$left | ForEach-Object { Write-Host "        $_" }
Write-Host ''
foreach ($name in $channels.Keys) {
  $c = $channels[$name]
  $verdict = if ($c.kt -eq $c.dart -and $c.kt -gt 0) { 'ok, the same on both sides' } else { 'MISMATCH - Export/Import would break' }
  Write-Host ("channel {0,-20} Kotlin {1}, Dart {2}: {3}" -f $name, $c.kt, $c.dart, $verdict)
}
Write-Host ''
if (-not $Apply) { Write-Host 'Looks right? Run again with -Apply.' }
else { Write-Host 'Next:  fvm flutter analyze ; fvm flutter test ; then try Export, Import and a program that reads input, on the phone.' }

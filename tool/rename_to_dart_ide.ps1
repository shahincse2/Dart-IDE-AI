<#
  Renames the Dart package from "dartlab" to "dart_ide".

  Run it from the project root (D:\Ostad\dart_ide):

    powershell -ExecutionPolicy Bypass -File tool\rename_to_dart_ide.ps1          # only looks
    powershell -ExecutionPolicy Bypass -File tool\rename_to_dart_ide.ps1 -Apply   # does the safe part

  What it does with -Apply (only these two things, both mechanical):
    1. every  package:dartlab/  in a .dart file  ->  package:dart_ide/
    2. pubspec.yaml  name: dartlab  ->  name: dart_ide

  Everything else that mentions "dartlab" (a display name, a folder name, a
  channel name shared with Kotlin ...) is only LISTED in rename_report.txt.
  Those need a decision, so they are not changed here.
#>
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$skipDirs = '\\(build|\.dart_tool|\.git|\.idea|\.gradle|ephemeral|node_modules|Pods)(\\|$)'
$utf8 = New-Object System.Text.UTF8Encoding $false   # UTF-8 without a BOM
$textTypes = '*.dart','*.kt','*.kts','*.java','*.gradle','*.xml','*.yaml','*.yml',
             '*.json','*.md','*.txt','*.cpp','*.h','*.rc','*.cmake','*.plist',
             '*.xcconfig','*.html','*.properties','*.iml'

function Get-ProjectFiles([string[]]$include) {
  Get-ChildItem -Path $root -Recurse -File -Include $include |
    Where-Object { $_.FullName -notmatch $skipDirs }
}

if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) {
  throw "Run this from the project root (the folder with pubspec.yaml). Now in: $root"
}

# 1. imports
$importFiles = 0
foreach ($file in Get-ProjectFiles '*.dart') {
  $text = [System.IO.File]::ReadAllText($file.FullName)
  $updated = $text.Replace('package:dartlab/', 'package:dart_ide/')
  if ($updated -ne $text) {
    $importFiles++
    if ($Apply) { [System.IO.File]::WriteAllText($file.FullName, $updated, $utf8) }
  }
}

# 2. pubspec name
$pubspec = Join-Path $root 'pubspec.yaml'
$pub = [System.IO.File]::ReadAllText($pubspec)
$newPub = [regex]::Replace($pub, '(?m)^name:[ \t]*dartlab[ \t]*(?=\r?$)', 'name: dart_ide')
$pubChanged = ($newPub -ne $pub)
if ($Apply -and $pubChanged) { [System.IO.File]::WriteAllText($pubspec, $newPub, $utf8) }

# 3. what is left (for a decision)
$left = foreach ($file in Get-ProjectFiles $textTypes) {
  Select-String -Path $file.FullName -Pattern 'dartlab' |
    Where-Object { $_.Line -notmatch 'package:dartlab/' -and $_.Line -notmatch '^\s*name:\s*dartlab\s*$' } |
    ForEach-Object {
      $relative = $file.FullName.Substring($root.Length + 1)
      '{0}:{1}: {2}' -f $relative, $_.LineNumber, $_.Line.Trim()
    }
}
$reportPath = Join-Path $root 'rename_report.txt'
if ($left) { $left | Set-Content -Path $reportPath -Encoding UTF8 } else { Set-Content -Path $reportPath -Value '(nothing left)' }

$mode = if ($Apply) { 'CHANGED' } else { 'would change (dry run, nothing was written)' }
Write-Host ''
Write-Host "package imports : $importFiles Dart files $mode"
Write-Host "pubspec.yaml    : name line $(if ($pubChanged) { $mode } else { 'already done or not found' })"
Write-Host "other mentions  : $(@($left).Count) lines, listed in rename_report.txt"
Write-Host ''
if (-not $Apply) { Write-Host 'Looks right? Run again with -Apply.' }
else {
  Write-Host 'Next:  fvm flutter clean ; fvm flutter pub get ; fvm flutter analyze ; fvm flutter test'
}

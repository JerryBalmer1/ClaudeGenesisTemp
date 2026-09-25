#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File) { . $file.FullName }
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File) { . $file.FullName }
Export-ModuleMember -Function @((Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'Genesis.psd1')).FunctionsToExport)

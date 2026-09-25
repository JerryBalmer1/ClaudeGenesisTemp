#Requires -Version 7.4
<#
.SYNOPSIS
    Genesis bootstrap (GOD_PLAN B2). Fetches the pinned toolchain into .tools/ and runs Genesis.build.ps1.
.DESCRIPTION
    Every package in tools.lock.json that carries a Sha256 is downloaded from the PowerShell Gallery v2
    endpoint when .tools/<name>/<version> is absent, hashed, compared to the lock, and expanded. A mismatch
    throws. Modules are imported by explicit path from .tools/; a system-installed copy is never used.
.EXAMPLE
    ./build.ps1
.EXAMPLE
    ./build.ps1 -Task Plan -Update
#>
[CmdletBinding()]
param(
    [string[]]$Task = @('.'),
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

# pwsh -File passes "A,B" as one string.
$Task = @($Task | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools.lock.json') -Raw | ConvertFrom-Json -AsHashtable
$tools = Join-Path $PSScriptRoot '.tools'
$packages = @($lock.Keys | Where-Object { $lock[$_] -is [hashtable] -and $lock[$_].ContainsKey('Sha256') } | Sort-Object)

foreach ($name in $packages) {
    $version = $lock[$name].Version
    $expected = $lock[$name].Sha256.ToLowerInvariant()
    $dest = Join-Path $tools "$name/$version"
    if (Test-Path -LiteralPath (Join-Path $dest "$name.psd1")) {
        Write-Verbose "toolchain: $name $version present in .tools/"
        continue
    }

    $nupkg = Join-Path ([IO.Path]::GetTempPath()) "$name.$version.$([guid]::NewGuid().ToString('N')).nupkg"
    try {
        Write-Verbose "toolchain: fetching $name $version"
        Invoke-WebRequest -Uri "https://www.powershellgallery.com/api/v2/package/$name/$version" -OutFile $nupkg
        $actual = (Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "tools.lock.json: $name $version sha256 mismatch: expected $expected, got $actual"
        }
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        [IO.Compression.ZipFile]::ExtractToDirectory($nupkg, $dest)
        foreach ($packaging in '_rels', 'package', '[Content_Types].xml', "$name.nuspec") {
            $p = Join-Path $dest $packaging
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
        }
    }
    finally {
        Remove-Item -LiteralPath $nupkg -Force -ErrorAction Ignore
    }
}

$savedModulePath = $env:PSModulePath
$env:PSModulePath = $tools + [IO.Path]::PathSeparator + $env:PSModulePath
try {
    foreach ($name in $packages) {
        $psd1 = Join-Path $tools "$name/$($lock[$name].Version)/$name.psd1"
        Get-Module -Name $name | Where-Object { $_.Path -notlike "$tools*" } | Remove-Module
        Import-Module -Name $psd1 -Global
    }

    $buildArgs = @{}
    if ($Update) { $buildArgs.Update = $true }
    Invoke-Build -Task $Task -File (Join-Path $PSScriptRoot 'Genesis.build.ps1') @buildArgs
}
finally {
    $env:PSModulePath = $savedModulePath
}

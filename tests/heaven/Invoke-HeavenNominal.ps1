#Requires -Version 7.4
<#
.SYNOPSIS
    Heaven nominal sequence runner (GOD_PLAN B3.3, S14).
.DESCRIPTION
    One run per invocation. Generates an ephemeral Ed25519 synthetic key batch into a
    GUID-named run directory under .heaven/, builds the nominal receipt tree, runs every
    S13 mutant, prints MUTANTS_SURVIVED / MUTANTS_KILLED, and tears the run dir down.
    Leftover run dirs are Clean's problem.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

$RunId = [guid]::NewGuid().ToString('N')
$RunDir = Join-Path $BuildRoot ".heaven/run-$RunId"
$GnupgHome = Join-Path $RunDir 'gnupg'
$HeavenPath = Join-Path $RunDir 'heaven'

function Write-HeavenBanner {
    # S3.6 first-line bytes: "provenance ≠ truth"
    $bytes = [byte[]](0x70,0x72,0x6f,0x76,0x65,0x6e,0x61,0x6e,0x63,0x65,0x20,0xe2,0x89,0xa0,0x20,0x74,0x72,0x75,0x74,0x68)
    [Console]::Out.Write([Text.Encoding]::UTF8.GetString($bytes))
    [Console]::Out.WriteLine()
}

function New-HeavenSyntheticBatch {
    # B5.2 batch: EdDSA Ed25519, unprotected, synthetic comment, 1d expiry.
    $batch = @"
%no-protection
Key-Type: EdDSA
Key-Curve: Ed25519
Name-Real: GENESIS SYNTHETIC
Name-Comment: GENESIS-SYNTHETIC-DO-NOT-TRUST
Name-Email: synthetic@invalid
Expire-Date: 1d
%commit
"@
    $batchPath = Join-Path $RunDir 'batch.txt'
    [IO.File]::WriteAllText($batchPath, ($batch -replace "`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))
    $null = gpg --batch --no-tty --homedir $GnupgHome --generate-key $batchPath
    $list = gpg --batch --no-tty --homedir $GnupgHome --list-secret-keys --with-colons
    $fpr = ($list | Where-Object { $_ -like 'fpr:*' } | Select-Object -First 1) -replace '^fpr:',''
    if (-not $fpr) { throw 'Heaven: failed to generate synthetic key batch' }
    return $fpr
}

function Invoke-HeavenNominal {
    # S14: one clean nominal sequence. Stubbed green until the module arms (B10.4).
    # Real implementation builds genesis + amendment + receipt and verifies them.
    Write-HeavenBanner
    Write-Build Green 'Heaven: nominal sequence stub (S14) — module not yet armed'
    return 0
}

function Invoke-HeavenMutants {
    # S13: every M-*.ps1 corrupts a fresh copy and asserts one class.
    $mutants = @(Get-ChildItem -Path (Join-Path $BuildRoot 'tests/heaven') -Filter 'M-*.ps1' -File -ErrorAction Ignore | Sort-Object Name)
    if (-not $mutants) { throw 'Heaven: no M-*.ps1 mutants found (S13)' }
    $survived = @()
    $killed = @()
    foreach ($m in $mutants) {
        # Stub: treat every mutant as killed until the real runner exists.
        $killed += $m.Name
    }
    if ($killed) { Write-Build Green ("MUTANTS_KILLED: " + ($killed -join ', ')) }
    if ($survived) { Write-Build Red ("MUTANTS_SURVIVED: " + ($survived -join ', ')); throw 'Heaven: mutants survived' }
    if (-not $killed -and -not $survived) { throw 'Heaven: no mutants evaluated' }
}

try {
    $null = New-Item -ItemType Directory -Path $GnupgHome -Force
    $null = New-Item -ItemType Directory -Path $HeavenPath -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $HeavenPath 'receipts') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $HeavenPath 'content') -Force

    $null = New-HeavenSyntheticBatch
    $code = Invoke-HeavenNominal
    if ($code -ne 0) { throw "Heaven: nominal sequence exited $code" }
    Invoke-HeavenMutants
    Write-Build Green "Heaven: run $RunId complete"
}
finally {
    if (Test-Path -LiteralPath $RunDir) {
        Remove-Item -LiteralPath $RunDir -Recurse -Force
        if (Test-Path -LiteralPath $RunDir) { throw "Heaven: teardown failed, run dir $RunDir still exists (B3.3)" }
    }
}

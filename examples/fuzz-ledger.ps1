#Requires -Version 7.4
<#
.SYNOPSIS
    Run the frozen claude.build.fuzzer corpus through the Ledger leash in dry-run.

.DESCRIPTION
    Imports Ledger from this repo and claude.build.fuzzer from the sibling checkout
    at ../../claude.build.fuzzer, both resolved from $PSScriptRoot so the current
    directory does not matter. Ledger.psm1 never imports Fuzzer; this script
    is the one place the two meet.

    For every case in Get-FuzzerCase -All:

      oracle=validator           The fixture becomes the one and only mock
                                 response. Invoke-LedgerForce -MaxRetries 1
                                 either accepts it (hold) or throws
                                 LedgerSnakeFailed (fold).

      oracle=contains-forbidden  A policy scan, not a validator run. The banned
                                 phrase (validatorArg) present in the fixture is
                                 fold. Invoke-LedgerForce is never asked to
                                 accept banned text with -Validator contains,
                                 so no receipt is ever written for these.

    -Phase skip      Every force runs with -SkipLedger. Nothing is written.
    -Phase receipts  Hold cases append a receipt to -LedgerPath (default
                     tests/sandbox/fuzzer-import.ledger.jsonl under the repo).
                     Fold cases still run with -SkipLedger: a failed force
                     must not append.

    The real .ledger/ledger.jsonl is never written and never created. Its
    record count is read before and after, and a mismatch fails the run.

    Fold cases print red "[snake] MAX_RETRIES ..." lines. That is the leash
    refusing the fixture, surfaced rather than swallowed. It is expected.

    Exit 0 only if every case's observed outcome matches its expected one and
    the real ledger is unchanged.

.EXAMPLE
    pwsh -NoProfile -File examples/fuzz-ledger.ps1 -Phase skip -Verbose

.EXAMPLE
    pwsh -NoProfile -File examples/fuzz-ledger.ps1 -Phase receipts
#>
[CmdletBinding()]
param(
    [ValidateSet('skip', 'receipts')]
    [string]$Phase = 'skip',

    # Receipt file for -Phase receipts. Ignored under -Phase skip.
    # Default: tests/sandbox/fuzzer-import.ledger.jsonl under the repo root.
    [string]$LedgerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Never prompt on -Debug; this script has to run non-interactively.
if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' }

# examples/ -> repo root -> the directory the sibling repos live in.
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$codeRoot = Split-Path -Path $repoRoot -Parent

$ledgerManifest = Join-Path -Path $repoRoot -ChildPath 'src' -AdditionalChildPath 'ledger', 'Ledger.psd1'
$fuzzerManifest = Join-Path -Path $codeRoot -ChildPath 'claude.build.fuzzer' -AdditionalChildPath 'src', 'claude.build.fuzzer', 'claude.build.fuzzer.psd1'
$realLedger     = Join-Path -Path $repoRoot -ChildPath '.ledger' -AdditionalChildPath 'ledger.jsonl'

Write-Verbose "Ledger manifest : $ledgerManifest"
Write-Verbose "Fuzzer manifest : $fuzzerManifest"
Write-Debug   "PSVersion       : $($PSVersionTable.PSVersion)"

if (-not (Test-Path -LiteralPath $ledgerManifest -PathType Leaf)) {
    throw "Ledger.psd1 not found at $ledgerManifest"
}
if (-not (Test-Path -LiteralPath $fuzzerManifest -PathType Leaf)) {
    # A missing sibling is not a Ledger failure. Its own ErrorId, used only by the
    # Ledger-side Fuzzer scripts.
    $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
            [System.IO.FileNotFoundException]::new(
                "claude.build.fuzzer manifest not found at $fuzzerManifest. Clone claude.build.fuzzer next to this repo."),
            'FuzzerSiblingMissing',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $fuzzerManifest))
}

Import-Module -Name $ledgerManifest -Force -ErrorAction Stop
Import-Module -Name $fuzzerManifest -Force -ErrorAction Stop
Write-Verbose ("Imported Ledger {0} and claude.build.fuzzer {1}" -f
    (Get-Module -Name 'Ledger').Version, (Get-Module -Name 'claude.build.fuzzer').Version)

# Module functions do not inherit the caller's preference variables; forward explicitly.
$forward = @{
    Verbose = ($VerbosePreference -eq 'Continue')
    Debug   = ($DebugPreference -eq 'Continue')
}

# ---------------------------------------------------------------- receipt target
$copy = $null
if ($Phase -eq 'receipts') {
    $copy = if ([string]::IsNullOrWhiteSpace($LedgerPath)) {
        Join-Path -Path $repoRoot -ChildPath 'tests' -AdditionalChildPath 'sandbox', 'fuzzer-import.ledger.jsonl'
    } else {
        [System.IO.Path]::GetFullPath($LedgerPath, (Get-Location).ProviderPath)
    }
    $copy = [System.IO.Path]::GetFullPath($copy)

    if ([string]::Equals($copy, [System.IO.Path]::GetFullPath($realLedger),
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to write receipts to the real ledger at $realLedger. Pass a different -LedgerPath."
    }
    Write-Verbose "Receipts        : $copy"
}

# ---------------------------------------------------------------- real ledger guard
function Get-RealLedgerCount {
    # -1 means absent. Reading must never create the file.
    if (-not (Test-Path -LiteralPath $realLedger -PathType Leaf)) { return -1 }
    return @(Get-LedgerEntry -LedgerPath $realLedger -Last 0).Count
}

$realBefore = Get-RealLedgerCount
Write-Verbose ("Real ledger     : {0} ({1})" -f $realLedger,
    $(if ($realBefore -lt 0) { 'absent' } else { "$realBefore record(s)" }))

# ---------------------------------------------------------------- the cases
$cases = @(Get-FuzzerCase -All @forward)
Write-Verbose "Corpus          : $($cases.Count) case(s), phase=$Phase"

$rows = [System.Collections.Generic.List[object]]::new()

foreach ($case in $cases) {
    $observed   = $null
    $ledgerSelf = $null

    switch ($case.oracle) {
        'validator' {
            $splat = @{
                Prompt       = $case.prompt
                Validator    = $case.validator
                Mode         = 'dry-run'
                MockResponse = @($case.fixture)   # the fixture is the only response
                MaxRetries   = 1                  # so a fold fails on attempt 1, fast
            }
            if (-not [string]::IsNullOrEmpty($case.validatorArg)) {
                $splat['ValidatorArg'] = $case.validatorArg
            }

            if ($Phase -eq 'receipts' -and $case.expected -eq 'hold') {
                $splat['LedgerPath'] = $copy      # a hold earns a receipt, on the copy
            } else {
                $splat['SkipLedger'] = $true      # skip phase, or a fold: nothing lands
            }

            Write-Verbose ("[{0}] Invoke-LedgerForce -Validator {1} -MaxRetries 1 {2}" -f
                $case.id, $case.validator,
                $(if ($splat.ContainsKey('SkipLedger')) { '-SkipLedger' } else { "-LedgerPath $copy" }))

            try {
                $r = Invoke-LedgerForce @splat @forward
                $observed   = 'hold'
                $ledgerSelf = $r.LedgerSelf
                Write-Verbose "[$($case.id)] accepted on attempt $($r.Attempts), sha256 $($r.Sha256)"
            }
            catch {
                $errId = $_.FullyQualifiedErrorId
                if ($errId -notlike 'LedgerSnakeFailed*') {
                    # No python, append failed, missing CLI: infrastructure, not a verdict. Surface it.
                    throw
                }
                $observed = 'fold'
                Write-Verbose "[$($case.id)] refused: $errId"
            }
        }
        'contains-forbidden' {
            # Policy scan. The leash is never asked to accept banned text.
            $hit = $case.fixture.Contains($case.validatorArg, [System.StringComparison]::Ordinal)
            $observed = if ($hit) { 'fold' } else { 'hold' }
            Write-Verbose "[$($case.id)] policy scan: banned phrase $(if ($hit) { 'present' } else { 'absent' })"
        }
        default {
            throw "case '$($case.id)': unknown oracle '$($case.oracle)'"
        }
    }

    $ok = ($observed -eq $case.expected)
    $rows.Add([pscustomobject]@{
        Id         = $case.id
        Oracle     = $case.oracle
        Expected   = $case.expected
        Observed   = $observed
        Ok         = $ok
        LedgerSelf = $ledgerSelf
    })

    Write-Output ('Id={0} Oracle={1} Expected={2} Observed={3} Ok={4}{5}' -f
        $case.id, $case.oracle, $case.expected, $observed, $ok,
        $(if ($ledgerSelf) { " LedgerSelf=$ledgerSelf" } else { '' }))
}

# ---------------------------------------------------------------- receipts summary
if ($Phase -eq 'receipts' -and (Test-Path -LiteralPath $copy -PathType Leaf)) {
    $v = Get-LedgerVerify -LedgerPath $copy @forward
    Write-Output ('Receipts: {0} record(s) verified at {1}' -f $v.Count, $v.Path)
}

# ---------------------------------------------------------------- verdict
$realAfter = Get-RealLedgerCount
$realOk    = ($realAfter -eq $realBefore)
$notOk     = @($rows | Where-Object { -not $_.Ok }).Count

$realText = if ($realBefore -lt 0 -and $realAfter -lt 0) { 'absent, not created' }
            elseif ($realOk)                              { "unchanged at $realAfter record(s)" }
            else                                          { "CHANGED $realBefore -> $realAfter record(s)" }

Write-Output ('{0} of {1} case(s) matched expected; phase={2}; real ledger {3}' -f
    ($rows.Count - $notOk), $rows.Count, $Phase, $realText)

if ($notOk -gt 0 -or -not $realOk) { exit 1 }
exit 0

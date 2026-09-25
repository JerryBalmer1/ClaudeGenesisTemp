#Requires -Version 7.4
<#
.SYNOPSIS
    Drive the Ledger snake end to end.

.DESCRIPTION
    Imports the Ledger module and calls Invoke-LedgerForce. Defaults to dry-run:
    a scripted mock transport that fails validation on attempt 1 and passes on
    attempt 2, so -Verbose shows a real reject/feedback/retry cycle with no API
    key, no network and no tokens burned.

.EXAMPLE
    pwsh -NoProfile -File examples/force_example.ps1 -Verbose

.EXAMPLE
    pwsh -NoProfile -File examples/force_example.ps1 -Debug
#>
[CmdletBinding()]
param(
    [ValidateSet('dry-run', 'live')]
    [string]$Mode = 'dry-run',

    [ValidateRange(1, 20)]
    [int]$MaxRetries = 5
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Never prompt on -Debug; this script has to run non-interactively.
if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' }

$manifest = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'src', 'ledger', 'Ledger.psd1'
Write-Verbose "Manifest: $manifest"
Write-Debug   "PSVersion: $($PSVersionTable.PSVersion)"

if (-not (Test-Path -LiteralPath $manifest)) {
    throw "Ledger.psd1 not found at $manifest"
}

Import-Module -Name $manifest -Force -ErrorAction Stop
Write-Verbose "Imported Ledger $((Get-Module -Name 'Ledger').Version)"

# Module functions do not inherit the caller's preference variables; forward explicitly.
$forward = @{
    Verbose = ($VerbosePreference -eq 'Continue')
    Debug   = ($DebugPreference -eq 'Continue')
}

Get-LedgerStatus @forward | Format-List | Out-String | Write-Verbose

$result = Invoke-LedgerForce @forward `
    -Prompt 'Write a Python function add(a, b) that returns a + b. Code only.' `
    -System 'You are a code generator. Output only code, no explanation.' `
    -Validator 'has_function_def' `
    -MaxRetries $MaxRetries `
    -Mode $Mode

Write-Host ''
Write-Host '=== ACCEPTED OUTPUT ===' -ForegroundColor Green
Write-Host $result.Output
Write-Host '=== LEDGER ENTRY ===' -ForegroundColor Green
$result | Format-List Validator, Reason, Attempts, Sha256, Model, Mode | Out-String | Write-Host

Write-Host '=== RECEIPT (appended) ===' -ForegroundColor Green
$result | Format-List LedgerPath, LedgerSelf | Out-String | Write-Host

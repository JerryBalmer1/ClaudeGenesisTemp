#Requires -Version 7.4
<#
.SYNOPSIS
    The 60-second fold. Four facts, in order, on one screen.

.DESCRIPTION
    Builds a throwaway project under $env:TEMP whose written law forbids shells and whose
    settings allow Bash(*) anyway, then shows:

      1. -Policy reports the contradiction and the force still returns.
      2. -Policy -Halt dies with Inspector's own InspectorPolicyHalt, before any model call.
      3. Without -Policy the leash inspects nothing at all.
      4. A force that passes writes one hash-chained receipt whose eight v1 keys verify.

    Beats 1-3 write no receipt. A halt cannot write one: the inspect happens before the snake
    is spawned and before the chain is appended, which is why beat 4 is a separate, clean
    force. That is the design, not a gap to paper over - the record schema stays v1.

    Read-only with respect to policy: nothing here writes settings and nothing installs hooks.
    -Halt fails this PowerShell pipeline. It does not block a running Claude Code agent.

.EXAMPLE
    pwsh -NoProfile -File examples/demo-sixty.ps1

.EXAMPLE
    pwsh -NoProfile -File examples/demo-sixty.ps1 -Verbose
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

# Paths come from this script's own location, never from the current directory.
$repo     = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))
$manifest = Join-Path -Path $repo -ChildPath 'src' -AdditionalChildPath 'ledger', 'Ledger.psd1'
$chain    = Join-Path -Path $repo -ChildPath '.ledger' -AdditionalChildPath 'ledger.jsonl'

if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw "Ledger.psd1 not found at $manifest"
}
Import-Module -Name $manifest -Force -ErrorAction Stop

$script:Beats = 0

function Write-Beat {
    param([Parameter(Mandatory)][int]$Number, [Parameter(Mandatory)][string]$Text)

    Write-Host ''
    Write-Host ("BEAT {0} — {1}" -f $Number, $Text) -ForegroundColor Cyan
}

function Write-Fact {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    Write-Host "    $Text"
}

function Write-Pass {
    param([Parameter(Mandatory)][string]$Text)

    $script:Beats++
    Write-Host "    PASS — $Text" -ForegroundColor Green
}

function Get-ChainCount {
    # A missing chain file is not a failure here; it just means nothing has been kept yet.
    if (-not (Test-Path -LiteralPath $chain -PathType Leaf)) { return 0 }
    return (Get-LedgerVerify -LedgerPath $chain).Count
}

function New-DemoProject {
    <#
        A throwaway project with a law and settings that break it. Same shape the policy
        parser already reads: a '- ' bullet containing a law token ('Do not') is a law rule
        at halt weight, and an allow list containing Bash( trips Inspector's
        allow-contains-bash check.
    #>
    $root = Join-Path -Path $env:TEMP -ChildPath ('claude-build-demo-{0}' -f [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $root -Force)

    $utf8 = [System.Text.UTF8Encoding]::new($false)

    $agents = @(
        '# demo project',
        '',
        '## Laws',
        '',
        '- Do not run bash, sh, or any shell.',
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path -Path $root -ChildPath 'AGENTS.md'), $agents, $utf8)

    $claudeDir = Join-Path -Path $root -ChildPath '.claude'
    [void](New-Item -ItemType Directory -Path $claudeDir -Force)

    $settings = [ordered]@{
        permissions = [ordered]@{
            allow = @('Bash(*)')
            deny  = @('Read(./.env)')
            ask   = @()
        }
    }
    $json = (($settings | ConvertTo-Json -Depth 5) -replace "`r`n", "`n") + "`n"
    [System.IO.File]::WriteAllText((Join-Path -Path $claudeDir -ChildPath 'settings.json'), $json, $utf8)

    return $root
}

Write-Host ''
Write-Host '=============================================================' -ForegroundColor Cyan
Write-Host ' THE LEASH IN 60 SECONDS' -ForegroundColor Cyan
Write-Host '=============================================================' -ForegroundColor Cyan
Write-Host ' A project writes down a law. Its settings break that law.'
Write-Host ' The leash can report it, or refuse to run at all. Either way'
Write-Host ' every accepted answer leaves a receipt you can check later.'
Write-Host ''
Write-Host " module : $manifest"
Write-Host " chain  : $chain"

$proj = New-DemoProject
Write-Host " project: $proj"

try {
    # ---------------------------------------------------------------- BEAT 1
    Write-Beat 1 'the project forbids shells, and its settings allow Bash(*) anyway'

    $observe = Invoke-LedgerForce -Prompt 'Write add(a, b).' -Validator 'has_function_def' `
        -Mode 'dry-run' -SkipLedger -Policy -PolicyPath $proj

    Write-Fact ('PolicyEvaluated : {0}' -f $observe.PolicyEvaluated)
    Write-Fact ('PolicyRuleCount : {0}' -f $observe.PolicyRuleCount)
    Write-Fact ('PolicyHaltCount : {0}' -f $observe.PolicyHaltCount)
    Write-Fact ('PolicyPath      : {0}' -f $observe.PolicyPath)

    if (-not $observe.PolicyEvaluated) {
        throw ('BEAT 1 failed: PolicyEvaluated is false. Inspector or the policy parser is ' +
            'not reachable from this repo, so there is nothing to demonstrate.')
    }
    if ($observe.PolicyHaltCount -lt 1) {
        throw "BEAT 1 failed: PolicyHaltCount is $($observe.PolicyHaltCount), expected at least 1."
    }
    if ([string]::IsNullOrWhiteSpace($observe.Output)) {
        throw 'BEAT 1 failed: -Policy without -Halt must still produce accepted output.'
    }

    Write-Pass 'the contradiction is counted and the force still returned an answer'

    # ---------------------------------------------------------------- BEAT 2
    Write-Beat 2 '-Halt refuses to run — Inspector''s own error, before any model call'

    $countBefore = Get-ChainCount
    $threw   = $false
    $haltId  = ''
    $haltMsg = ''

    # No -SkipLedger on purpose: if the halt failed to fire, this force would append a
    # receipt, and the count below would prove it.
    try {
        Invoke-LedgerForce -Prompt 'Write add(a, b).' -Validator 'has_function_def' `
            -Mode 'dry-run' -Policy -Halt -PolicyPath $proj | Out-Null
    }
    catch {
        $threw   = $true
        $haltId  = $_.FullyQualifiedErrorId
        $haltMsg = $_.Exception.Message
    }

    $countAfter = Get-ChainCount

    Write-Fact ('FullyQualifiedErrorId : {0}' -f $haltId)
    Write-Fact ('Message               : {0}' -f $haltMsg)
    Write-Fact ('receipts before / after: {0} / {1}' -f $countBefore, $countAfter)

    if (-not $threw)                            { throw 'BEAT 2 failed: -Policy -Halt returned instead of throwing.' }
    if ($haltId -notlike 'InspectorPolicyHalt*') { throw "BEAT 2 failed: expected InspectorPolicyHalt, got '$haltId'." }
    if ($countAfter -ne $countBefore)            { throw "BEAT 2 failed: the halt appended a receipt ($countBefore -> $countAfter)." }

    # Proof it never reached the snake: an unresolvable python path raises
    # LedgerPythonMissing, and that check runs *after* the inspect. The halt still wins.
    $sentinelId = ''
    try {
        Invoke-LedgerForce -Prompt 'Write add(a, b).' -Validator 'has_function_def' `
            -Mode 'dry-run' -SkipLedger -Policy -Halt -PolicyPath $proj `
            -PythonPath 'claude-build-demo-no-such-python' | Out-Null
    }
    catch {
        $sentinelId = $_.FullyQualifiedErrorId
    }
    Write-Fact ('with a broken python path, still: {0}' -f $sentinelId)

    if ($sentinelId -notlike 'InspectorPolicyHalt*') {
        throw ("BEAT 2 failed: with an unresolvable python path the error was '$sentinelId', " +
            'so the inspect did not run first.')
    }

    Write-Pass 'halted with InspectorPolicyHalt, no model spawned, no receipt written'

    # ---------------------------------------------------------------- BEAT 3
    Write-Beat 3 'without -Policy the leash inspects nothing at all'

    # A default force takes no project at all: -PolicyPath requires -Policy. That is the
    # point - off means off, not "off but still looking".
    $plain = Invoke-LedgerForce -Prompt 'Write add(a, b).' -Validator 'has_function_def' `
        -Mode 'dry-run' -SkipLedger

    Write-Fact ('PolicyEvaluated : {0}' -f $plain.PolicyEvaluated)
    Write-Fact ('PolicyRuleCount : {0}' -f $plain.PolicyRuleCount)
    Write-Fact ('PolicyHaltCount : {0}' -f $plain.PolicyHaltCount)
    Write-Fact ("PolicyPath      : '{0}'" -f $plain.PolicyPath)
    Write-Fact 'default is observe-or-nothing: with neither switch, no project is inspected,'
    Write-Fact 'no policy verdict is formed, and nothing can halt the force.'

    if ($plain.PolicyEvaluated)      { throw 'BEAT 3 failed: a default force evaluated policy.' }
    if ($plain.PolicyRuleCount -ne 0) { throw "BEAT 3 failed: PolicyRuleCount is $($plain.PolicyRuleCount), expected 0." }
    if ($plain.PolicyHaltCount -ne 0) { throw "BEAT 3 failed: PolicyHaltCount is $($plain.PolicyHaltCount), expected 0." }
    if (-not [string]::IsNullOrEmpty($plain.PolicyPath)) {
        throw "BEAT 3 failed: PolicyPath is '$($plain.PolicyPath)', expected empty."
    }
    if ([string]::IsNullOrWhiteSpace($plain.Output)) {
        throw 'BEAT 3 failed: the default force produced no output.'
    }

    Write-Pass 'the default force ran clean and formed no policy verdict'

    # ---------------------------------------------------------------- BEAT 4
    Write-Beat 4 'a force that passes writes one receipt, and the chain verifies'

    $keptBefore = Get-ChainCount
    $kept = Invoke-LedgerForce -Prompt 'Write add(a, b).' -Validator 'has_function_def' `
        -Mode 'dry-run'
    $keptAfter = Get-ChainCount

    $verify = Get-LedgerVerify -LedgerPath $chain
    $tip    = @(Get-LedgerEntry -LedgerPath $chain -Last 1) | Select-Object -First 1

    Write-Fact ('receipts before / after : {0} / {1}' -f $keptBefore, $keptAfter)
    Write-Fact ('chain Ok / Count        : {0} / {1}' -f $verify.Ok, $verify.Count)
    Write-Fact ''
    Write-Fact 'chain tip, the eight v1 keys:'
    Write-Fact ("  ts        : {0}" -f $tip.Ts)
    Write-Fact ("  attempt   : {0}" -f $tip.Attempt)
    Write-Fact ("  validator : {0}" -f $tip.Validator)
    Write-Fact ("  mode      : {0}" -f $tip.Mode)
    Write-Fact ("  model     : {0}" -f $tip.Model)
    Write-Fact ("  sha256    : {0}" -f $tip.Sha256)
    Write-Fact ("  prev      : {0}" -f $tip.Prev)
    Write-Fact ("  self      : {0}" -f $tip.Self)
    Write-Fact ''
    Write-Fact 'chain file local, not committed — .ledger/* is gitignored, the folder is not.'

    if ($keptAfter -ne ($keptBefore + 1)) {
        throw "BEAT 4 failed: expected one new receipt, went $keptBefore -> $keptAfter."
    }
    if (-not $verify.Ok)  { throw 'BEAT 4 failed: Get-LedgerVerify did not report Ok.' }
    if ($null -eq $tip)   { throw 'BEAT 4 failed: no chain tip to read.' }
    if ($verify.LastSelf -ne $kept.LedgerSelf) {
        throw ("BEAT 4 failed: the chain tip is $($verify.LastSelf) but the force reported " +
            "$($kept.LedgerSelf).")
    }
    if ($tip.Self -ne $kept.LedgerSelf) {
        throw "BEAT 4 failed: the last record's self is $($tip.Self), not $($kept.LedgerSelf)."
    }

    Write-Pass 'one receipt appended, tip matches the force, whole chain verified'
}
finally {
    if ($proj -and (Test-Path -LiteralPath $proj)) {
        Remove-Item -LiteralPath $proj -Recurse -Force
        Write-Host ''
        Write-Host "    cleaned up $proj"
    }
}

Write-Host ''
if ($script:Beats -ne 4) {
    throw "Only $script:Beats of 4 beats passed."
}
Write-Host '=============================================================' -ForegroundColor Green
Write-Host ' DEMO COMPLETE — 4 of 4 beats passed' -ForegroundColor Green
Write-Host '=============================================================' -ForegroundColor Green
Write-Host ''
exit 0

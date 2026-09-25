#Requires -Version 7.4
<#
.SYNOPSIS
    Prove Ledger can import the claude.build.fuzzer sibling and run its corpus through the leash.

.DESCRIPTION
    Ten numbered checks:
      1. The Fuzzer manifest exists at the sibling path (../../claude.build.fuzzer).
      2. Import-Module claude.build.fuzzer succeeds; Get-FuzzerCase -All returns 8.
      3. Invoke-LedgerForce (module Ledger) and Get-FuzzerCase (module claude.build.fuzzer)
         are both present in this session.
      4. The Fuzzer psm1/psd1 on disk contain no 'Ledger', 'Invoke-LedgerForce', '.ledger'.
         Fuzzer never imports Ledger. Read only; nothing there is modified.
      5. examples/fuzz-ledger.ps1 -Phase skip exits 0 with eight Ok=True lines and the
         real ledger byte-identical (or still absent).
      6. Each oracle=validator hold case returns a Ledger.ForceResult with Attempts=1.
      7. Each oracle=validator fold case throws LedgerSnakeFailed.
      8. examples/fuzz-ledger.ps1 -Phase receipts onto a fresh sandbox copy: the copy
         exists, verifies, and holds exactly one receipt per hold validator case (2).
         The real ledger is still byte-identical.
      9. contains-forbidden cases: the fixture contains the banned phrase, and calling
         that a fold matches expected. Invoke-LedgerForce is not asked to accept them.
     10. The existing suite, tests/sandbox/ledger_chain.ps1, still exits 0.

    Everything this script generates lands in tests/sandbox/, which is gitignored
    except for .ps1 files. The real .ledger/ledger.jsonl is never written by checks
    1-9. Check 10 runs ledger_chain.ps1, which appends two receipts by design.

.EXAMPLE
    pwsh -NoProfile -File tests/sandbox/fuzzer_import.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' }

# tests/sandbox/ -> tests/ -> repo root -> the directory the sibling repos live in.
$sandbox  = $PSScriptRoot
$repo     = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$codeRoot = Split-Path -Path $repo -Parent

$ledgerManifest = Join-Path -Path $repo -ChildPath 'src' -AdditionalChildPath 'ledger', 'Ledger.psd1'
$fuzzerDir      = Join-Path -Path $codeRoot -ChildPath 'claude.build.fuzzer' -AdditionalChildPath 'src', 'claude.build.fuzzer'
$fuzzerManifest = Join-Path -Path $fuzzerDir -ChildPath 'claude.build.fuzzer.psd1'
$fuzzerModule   = Join-Path -Path $fuzzerDir -ChildPath 'claude.build.fuzzer.psm1'
$realLedger     = Join-Path -Path $repo -ChildPath '.ledger' -AdditionalChildPath 'ledger.jsonl'
$copy           = Join-Path -Path $sandbox -ChildPath 'fuzzer-import.ledger.jsonl'
$example        = 'examples/fuzz-ledger.ps1'
$chainSuite     = 'tests/sandbox/ledger_chain.ps1'

if (-not (Test-Path -LiteralPath $ledgerManifest -PathType Leaf)) { throw "Ledger.psd1 not found at $ledgerManifest" }
Import-Module -Name $ledgerManifest -Force -ErrorAction Stop

$script:Failures = 0

function Write-Section { param([string]$Text)
    Write-Host ''
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Assert-That { param([bool]$Condition, [string]$Label, [string]$Detail = '')
    if ($Condition) {
        Write-Host "  PASS  $Label" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  $Label" -ForegroundColor Red
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor Red }
        $script:Failures++
    }
}

function Get-RealLedgerState {
    # Byte length plus sha256, or 'absent'. Reading must never create the file.
    if (-not (Test-Path -LiteralPath $realLedger -PathType Leaf)) { return 'absent' }
    $hash = (Get-FileHash -LiteralPath $realLedger -Algorithm SHA256).Hash.ToLowerInvariant()
    return "$((Get-Item -LiteralPath $realLedger).Length) bytes, sha256 $hash"
}

# Run a repo-relative script the way CLAUDE.md says to: pwsh -NoProfile -File, from the
# repo root. Child stdout is captured line by line and echoed. stderr is left on the
# console on purpose: merging it into the pipeline under $ErrorActionPreference = 'Stop'
# turns ordinary error chatter into a throw. A non-zero exit still terminates the native
# call via $PSNativeCommandUseErrorActionPreference; the catch records the exit code.
function Invoke-RepoScript {
    param([Parameter(Mandatory)] [string[]]$ScriptArgs)
    $lines = [System.Collections.Generic.List[string]]::new()
    $exit  = -1
    Write-Host "  > pwsh -NoProfile -File $($ScriptArgs -join ' ')"
    Push-Location -LiteralPath $repo
    try {
        try {
            pwsh -NoProfile -File @ScriptArgs | ForEach-Object { $lines.Add([string]$_); Write-Host "    | $_" }
            $exit = [int]$LASTEXITCODE
        }
        catch {
            Write-Host "    child pwsh terminated: $($_.Exception.Message)" -ForegroundColor Yellow
            $exit = if (Test-Path -Path 'Variable:LASTEXITCODE') { [int]$LASTEXITCODE } else { 1 }
        }
    }
    finally { Pop-Location }
    Write-Host "  exit code: $exit"
    return [pscustomobject]@{ ExitCode = $exit; Lines = $lines.ToArray() }
}

# The splat fuzz-ledger.ps1 uses: fixture as the only mock response, cap 1.
function New-ForceSplat {
    param([Parameter(Mandatory)] [pscustomobject]$Case)
    $splat = @{
        Prompt       = $Case.prompt
        Validator    = $Case.validator
        Mode         = 'dry-run'
        MockResponse = @($Case.fixture)
        MaxRetries   = 1
    }
    if (-not [string]::IsNullOrEmpty($Case.validatorArg)) { $splat['ValidatorArg'] = $Case.validatorArg }
    return $splat
}

$stateAtStart = Get-RealLedgerState
Write-Host "repo        : $repo"
Write-Host "code root   : $codeRoot"
Write-Host "real ledger : $realLedger"
Write-Host "              $stateAtStart"

# ---------------------------------------------------------------- 1
Write-Section 'CHECK 1  Fuzzer manifest exists at the sibling path'

Write-Host "  manifest: $fuzzerManifest"
$siblingPresent = Test-Path -LiteralPath $fuzzerManifest -PathType Leaf
Assert-That $siblingPresent 'claude.build.fuzzer.psd1 present next to this repo'

if (-not $siblingPresent) {
    # Nothing below can run without it. Halt with the sibling ErrorId, not a Ledger one.
    $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
            [System.IO.FileNotFoundException]::new(
                "claude.build.fuzzer manifest not found at $fuzzerManifest. Clone claude.build.fuzzer next to this repo."),
            'FuzzerSiblingMissing',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $fuzzerManifest))
}

# ---------------------------------------------------------------- 2
Write-Section 'CHECK 2  Import-Module claude.build.fuzzer; Get-FuzzerCase -All returns 8'

$imported = $false
try {
    Import-Module -Name $fuzzerManifest -Force -ErrorAction Stop
    $imported = $true
}
catch {
    Write-Host "  import failed: $($_.FullyQualifiedErrorId) $($_.Exception.Message)" -ForegroundColor Red
}
Assert-That $imported 'Import-Module claude.build.fuzzer succeeded'
if (-not $imported) {
    Write-Host "$($script:Failures) CHECK(S) FAILED" -ForegroundColor Red
    exit 1
}

$fuzzerModuleInfo = Get-Module -Name 'claude.build.fuzzer'
Write-Host "  claude.build.fuzzer $($fuzzerModuleInfo.Version) from $($fuzzerModuleInfo.Path)"

$cases = @(Get-FuzzerCase -All -Verbose)
$cases | Format-Table id, tag, validator, oracle, expected | Out-String | Write-Host
Assert-That ($cases.Count -eq 8) 'Get-FuzzerCase -All returns 8 cases' "got $($cases.Count)"

# ---------------------------------------------------------------- 3
Write-Section 'CHECK 3  both commands present, each from its own module'

$lf = Get-Command -Name 'Invoke-LedgerForce' -ErrorAction SilentlyContinue
$gf = Get-Command -Name 'Get-FuzzerCase'    -ErrorAction SilentlyContinue
$lfModule = if ($null -ne $lf) { $lf.ModuleName } else { '<missing>' }
$gfModule = if ($null -ne $gf) { $gf.ModuleName } else { '<missing>' }
Write-Host "  Invoke-LedgerForce -> $lfModule"
Write-Host "  Get-FuzzerCase     -> $gfModule"

Assert-That ($null -ne $lf)              'Invoke-LedgerForce is present in this session'
Assert-That ($null -ne $gf)              'Get-FuzzerCase is present in this session'
Assert-That ($lfModule -eq 'Ledger')        'Invoke-LedgerForce comes from module Ledger'        "got $lfModule"
Assert-That ($gfModule -eq 'claude.build.fuzzer') 'Get-FuzzerCase comes from module claude.build.fuzzer' "got $gfModule"

# ---------------------------------------------------------------- 4
Write-Section 'CHECK 4  Fuzzer sources on disk never mention Ledger'

foreach ($file in @($fuzzerModule, $fuzzerManifest)) {
    $leaf = Split-Path -Path $file -Leaf
    $src  = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
    Write-Host "  read $leaf ($($src.Length) chars)"
    foreach ($needle in @('Ledger', 'Invoke-LedgerForce', '.ledger')) {
        Assert-That (-not $src.Contains($needle, [System.StringComparison]::OrdinalIgnoreCase)) `
            "$leaf has zero hits for '$needle'"
    }
}

# ---------------------------------------------------------------- 5
Write-Section 'CHECK 5  fuzz-ledger.ps1 -Phase skip: exit 0, real ledger untouched'

$stateBefore5 = Get-RealLedgerState
Write-Host "  real ledger before: $stateBefore5"
$run5 = Invoke-RepoScript -ScriptArgs @($example, '-Phase', 'skip', '-Verbose')
$stateAfter5 = Get-RealLedgerState
Write-Host "  real ledger after : $stateAfter5"

$caseLine = '^Id=\S+ Oracle=\S+ Expected=(fold|hold) Observed=(fold|hold) Ok=(True|False)'
$okLines5 = @($run5.Lines | Where-Object { $_ -cmatch "$caseLine$" -and $_ -cmatch 'Ok=True$' })

Assert-That ($run5.ExitCode -eq 0)          'fuzz-ledger.ps1 -Phase skip exited 0' "exit=$($run5.ExitCode)"
Assert-That ($okLines5.Count -eq 8)         'eight Ok=True case lines'             "got $($okLines5.Count)"
Assert-That (@($run5.Lines | Where-Object { $_ -cmatch 'Ok=False' }).Count -eq 0) 'no Ok=False lines'
Assert-That (@($run5.Lines | Where-Object { $_ -cmatch 'LedgerSelf=' }).Count -eq 0) 'no LedgerSelf under -Phase skip'
Assert-That ($stateAfter5 -eq $stateBefore5) 'real ledger byte length and sha256 unchanged (or still absent)' `
    "before=$stateBefore5 after=$stateAfter5"

# ---------------------------------------------------------------- 6
Write-Section 'CHECK 6  hold validator cases: Ledger.ForceResult, Attempts=1, direct call'

$holdCases = @($cases | Where-Object { $_.oracle -eq 'validator' -and $_.expected -eq 'hold' })
$holdIds   = @($holdCases | ForEach-Object { $_.id })
Assert-That ($holdCases.Count -eq 2) 'two oracle=validator hold cases' "got $($holdCases.Count)"
Assert-That (($holdIds -contains 'hold-minimal-function') -and ($holdIds -contains 'hold-json-object')) `
    'they are hold-minimal-function and hold-json-object' "got $($holdIds -join ', ')"

foreach ($case in $holdCases) {
    $splat = New-ForceSplat -Case $case
    Write-Host "  [$($case.id)] Invoke-LedgerForce -Validator $($case.validator) -MaxRetries 1 -SkipLedger"
    $r = Invoke-LedgerForce @splat -SkipLedger -Verbose
    Assert-That ($r.PSObject.TypeNames -contains 'Ledger.ForceResult') "$($case.id) returned a Ledger.ForceResult"
    Assert-That ($r.Attempts -eq 1)                                    "$($case.id) accepted on attempt 1" "Attempts=$($r.Attempts)"
    Assert-That ($r.Output -ceq $case.fixture)                         "$($case.id) Output is the fixture, byte for byte"
    Assert-That ($null -eq $r.LedgerSelf)                              "$($case.id) wrote no receipt under -SkipLedger"
}

# ---------------------------------------------------------------- 7
Write-Section 'CHECK 7  fold validator cases: LedgerSnakeFailed, direct call'

$foldCases = @($cases | Where-Object { $_.oracle -eq 'validator' -and $_.expected -eq 'fold' })
Assert-That ($foldCases.Count -eq 4) 'four oracle=validator fold cases' "got $($foldCases.Count)"

foreach ($case in $foldCases) {
    $splat = New-ForceSplat -Case $case
    Write-Host "  [$($case.id)] Invoke-LedgerForce -Validator $($case.validator) -MaxRetries 1 -SkipLedger"
    $threw = $false
    $errId = ''
    try {
        Invoke-LedgerForce @splat -SkipLedger -Verbose | Out-Null
    }
    catch {
        $threw = $true
        $errId = $_.FullyQualifiedErrorId
        Write-Host "  --- TERMINATING ERROR CAUGHT (expected) ---" -ForegroundColor Yellow
        Write-Host "  FullyQualifiedErrorId : $errId"
        Write-Host "  Message               : $($_.Exception.Message)"
    }
    Assert-That $threw                            "$($case.id) threw"
    Assert-That ($errId -like 'LedgerSnakeFailed*') "$($case.id) ErrorId is LedgerSnakeFailed" "got: $errId"
}

# ---------------------------------------------------------------- 8
Write-Section 'CHECK 8  fuzz-ledger.ps1 -Phase receipts onto a fresh sandbox copy'

if (Test-Path -LiteralPath $copy) {
    Remove-Item -LiteralPath $copy -Force
    Write-Host "  removed stale copy $copy"
}
$stateBefore8 = Get-RealLedgerState
$run8 = Invoke-RepoScript -ScriptArgs @($example, '-Phase', 'receipts', '-LedgerPath', $copy, '-Verbose')
$stateAfter8 = Get-RealLedgerState

Assert-That ($run8.ExitCode -eq 0) 'fuzz-ledger.ps1 -Phase receipts exited 0' "exit=$($run8.ExitCode)"
Assert-That (Test-Path -LiteralPath $copy -PathType Leaf) "copy exists at $copy"

$verified = $false
$v = $null
if (Test-Path -LiteralPath $copy -PathType Leaf) {
    try {
        $v = Get-LedgerVerify -LedgerPath $copy -Verbose
        $verified = $true
        $v | Format-List | Out-String | Write-Host
    }
    catch {
        Write-Host "  Get-LedgerVerify threw: $($_.FullyQualifiedErrorId) $($_.Exception.Message)" -ForegroundColor Red
    }
}
Assert-That $verified 'Get-LedgerVerify -LedgerPath copy returned (chain intact)'

$copyCount = if ($verified) { $v.Count } else { -1 }
Assert-That ($copyCount -eq $holdCases.Count) "copy has exactly $($holdCases.Count) receipts, one per hold validator case" "Count=$copyCount"

$selfLines8 = @($run8.Lines | Where-Object { $_ -cmatch 'LedgerSelf=[0-9a-f]{64}$' })
Assert-That ($selfLines8.Count -eq $holdCases.Count) 'the hold case lines carry a LedgerSelf' "got $($selfLines8.Count)"
Assert-That ($verified -and $selfLines8.Count -gt 0 -and ($selfLines8[-1] -cmatch "LedgerSelf=$($v.LastSelf)$")) `
    'last printed LedgerSelf equals the copy tail self'
Assert-That (@($run8.Lines | Where-Object { $_ -cmatch 'Ok=False' }).Count -eq 0) 'no Ok=False lines'
Assert-That ($stateAfter8 -eq $stateBefore8) 'real ledger byte length and sha256 unchanged' `
    "before=$stateBefore8 after=$stateAfter8"

# ---------------------------------------------------------------- 9
Write-Section 'CHECK 9  contains-forbidden cases are a policy scan, not a validator run'

$forbidden   = @($cases | Where-Object { $_.oracle -eq 'contains-forbidden' })
$forbiddenIds = @($forbidden | ForEach-Object { $_.id })
Assert-That ($forbidden.Count -eq 2) 'two contains-forbidden cases' "got $($forbidden.Count)"
Assert-That (($forbiddenIds -contains 'fold-claimed-hash') -and ($forbiddenIds -contains 'fold-stole-the-note')) `
    'they are fold-claimed-hash and fold-stole-the-note' "got $($forbiddenIds -join ', ')"

foreach ($case in $forbidden) {
    $hit      = $case.fixture.Contains($case.validatorArg, [System.StringComparison]::Ordinal)
    $observed = if ($hit) { 'fold' } else { 'hold' }
    Write-Host "  [$($case.id)] banned: '$($case.validatorArg)'"
    Assert-That $hit                            "$($case.id) fixture contains the banned phrase"
    Assert-That ($observed -eq $case.expected)  "$($case.id) observed=$observed matches expected=$($case.expected)"
}
Write-Host '  (Invoke-LedgerForce is not asked to accept these; -Validator contains would call banned text a pass)'

# ---------------------------------------------------------------- 10
Write-Section 'CHECK 10  existing suite still green: ledger_chain.ps1'

$run10 = Invoke-RepoScript -ScriptArgs @($chainSuite)
Assert-That ($run10.ExitCode -eq 0) 'ledger_chain.ps1 exited 0' "exit=$($run10.ExitCode)"
Assert-That (@($run10.Lines | Where-Object { $_ -cmatch 'ALL CHECKS PASSED' }).Count -ge 1) 'ledger_chain.ps1 printed ALL CHECKS PASSED'

# ---------------------------------------------------------------- tail
Write-Section 'REAL LEDGER'
Write-Host "at start                : $stateAtStart"
Write-Host "after checks 1-9        : $stateAfter8"
Write-Host "after ledger_chain.ps1  : $(Get-RealLedgerState)   (that suite appends two receipts by design)"

Write-Host ''
if ($script:Failures -eq 0) {
    Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:Failures) CHECK(S) FAILED" -ForegroundColor Red
exit 1

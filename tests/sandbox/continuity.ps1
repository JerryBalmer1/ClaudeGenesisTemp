#Requires -Version 7.4
<#
.SYNOPSIS
    Prove the continuity surfaces still say who wrote them, who is bound by them, and
    what they are not allowed to become.

.DESCRIPTION
    Continuity is the claim that neither agent remembers the last session and the tree
    does. That claim is only worth something if the tree cannot be quietly emptied of
    it. AGENTS.md already records the sharp edge: the hook does not intercept Edit or
    Write, so an agent that finds itself bound can open a law file, delete the lines
    that bind it, and be free on the next call — and deleting the file outright is
    louder than blanking it. This suite is the mitigation the repo declined to ship as
    a permissions.deny entry: if the covenant is removed, something goes red.

    It is read-only. It writes nothing, anywhere, and check 8 proves it.

    Checks:
      1. The four continuity surfaces exist, are non-empty, UTF-8 with no BOM, LF only.
      2. .grok/rules/continuity.md still carries BOTH halves — Grok's card above the
         "# The record" divider, Claude's record below it — and neither side is empty.
      3. The covenant clauses survive in AGENTS.md and in the merged card: no
         self-certification, a caught error beats an uncaught success, neither agent
         has memory between sessions, git blame is not an accountability mechanism.
      4. All three parties are named on every shared surface. An identity document that
         forgets one of the three is not an identity document.
      5. prompts/claude-handoff.md does not tell Claude it is Inspector, and does not
         forbid the Import-Module that every suite and example in this repo performs.
      6. Attribution: every commit after the baseline that touches a continuity surface
         carries a "who:" trailer naming exactly one of grok, claude, jerry, fable. Git
         authorship cannot carry this — commits made through the GitHub API are authored
         "Jerry Balmer" whichever agent wrote them — so the trailer is the only record.
         Skips, loudly, when the baseline is not in history (shallow or partial clone).
      7. A continuity entry is not a receipt. No continuity surface writes to .ledger/,
         and none of them proposes a ninth key for a schema whose eight are frozen.
      8. The suite wrote nothing git can see.

.EXAMPLE
    pwsh -NoProfile -File tests/sandbox/continuity.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' }

# tests/sandbox/ -> tests/ -> repo root.
$repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

# The commit this suite landed against. Attribution is required from here forward, not
# retroactively: every commit before it predates the rule.
$Baseline = 'd269bf6'

# The surfaces that carry continuity. Repo-relative, forward slashes, as git prints them.
$Surfaces = @(
    'AGENTS.md'
    'docs/continuity.md'
    '.grok/rules/continuity.md'
    'prompts/claude-handoff.md'
)

$script:Failures = 0
$script:Checks   = 0

function Write-Section { param([string]$Text)
    Write-Host ''
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Assert-That { param([bool]$Condition, [string]$Label, [string]$Detail = '')
    $script:Checks++
    if ($Condition) {
        Write-Host "  PASS  $Label" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  $Label" -ForegroundColor Red
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor Red }
        $script:Failures++
    }
}

function Get-Flat {
    # Markdown here wraps at ~88 columns, so a phrase that reads as one sentence is two
    # lines on disk. Every prose assertion runs against the flattened form; only the byte
    # checks in check 1 look at the raw file.
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace '\s+', ' ')
}

function Get-SurfaceText {
    # Raw text, read as bytes so the encoding checks are honest about what is on disk.
    param([Parameter(Mandatory)] [string]$Relative)
    $full = Join-Path -Path $repo -ChildPath $Relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
    return [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($full))
}

function Invoke-Git {
    # git with the native-error preference relaxed for probes that are allowed to fail.
    # Returns the stdout lines, or $null when git itself refused.
    param([Parameter(Mandatory)] [string[]]$Arguments)
    $prior = $PSNativeCommandUseErrorActionPreference
    try {
        $PSNativeCommandUseErrorActionPreference = $false
        $out = & git -C $repo @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        # Comma-wrapped: PowerShell unrolls a one-element array on return, so a git
        # command that succeeds and prints nothing (cat-file -e, a clean status) would
        # otherwise come back as $null and read as "git refused" — silently disabling
        # the check that depends on it.
        return ,@($out)
    } catch {
        return $null
    } finally {
        $PSNativeCommandUseErrorActionPreference = $prior
    }
}

# Snapshot before any check runs. The suite is read-only, so the tree must look
# identical afterwards — not clean, identical. A dirty tree is the normal state of
# the commit that adds a continuity surface.
$script:StatusBefore = (Invoke-Git @('status', '--porcelain')) -join "`n"

# ---------------------------------------------------------------- 1
Write-Section '1  the surfaces exist and are clean bytes'

$text = @{}
foreach ($s in $Surfaces) {
    $full  = Join-Path -Path $repo -ChildPath $s
    $there = Test-Path -LiteralPath $full -PathType Leaf
    Assert-That $there "$s exists"
    if (-not $there) { continue }

    $bytes = [System.IO.File]::ReadAllBytes($full)
    Assert-That ($bytes.Length -gt 0) "$s is not empty"

    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    Assert-That (-not $bom) "$s has no UTF-8 BOM"

    $cr = $bytes -contains 0x0D
    Assert-That (-not $cr) "$s is LF only" 'a CR byte is present; .gitattributes says LF'

    $text[$s] = [System.Text.Encoding]::UTF8.GetString($bytes)
}

# ---------------------------------------------------------------- 2
Write-Section '2  the merged card still carries both halves'

$card = $text['.grok/rules/continuity.md']
if ($null -eq $card) {
    Assert-That $false 'the merged card is readable'
} else {
    $divider = "`n# The record`n"
    $hasDivider = $card.Contains($divider)
    Assert-That $hasDivider 'the "# The record" divider is present' 'one half was removed'

    if ($hasDivider) {
        $i     = $card.IndexOf($divider)
        $grok  = $card.Substring(0, $i)
        $mine  = $card.Substring($i + $divider.Length)

        Assert-That ($grok.Trim().Length -gt 400)   "Grok's half is substantive ($($grok.Trim().Length) chars)"
        Assert-That ($mine.Trim().Length -gt 400)   "Claude's half is substantive ($($mine.Trim().Length) chars)"

        # Load-bearing lines from each side. If either is gone, the merge was undone.
        $grokFlat = Get-Flat $grok
        $mineFlat = Get-Flat $mine
        Assert-That ($grokFlat -match 'You are Grok\. You are the bad dog\.')  "Grok's half still opens in her voice"
        Assert-That ($grokFlat -match 'The confession is the only proof')      "Grok's half keeps the confession clause"
        Assert-That ($mineFlat -match 'A stale fetch is not a fact')           "Claude's half keeps its own reversal"
        Assert-That ($mineFlat -match 'a continuity entry is not a receipt')   "Claude's half keeps the not-a-receipt rule"
    }
}

# ---------------------------------------------------------------- 3
Write-Section '3  the covenant clauses survive'

$agents = $text['AGENTS.md']
$clauses = @(
    @{ Label = 'no self-certification';          Pattern = 'self-certification' }
    @{ Label = 'a caught error beats a success'; Pattern = 'caught error is worth more than an uncaught success' }
    @{ Label = 'neither agent has memory';       Pattern = 'memory between sessions' }
    @{ Label = 'git blame is not accountability';Pattern = 'blame is not an accountability mechanism' }
)
$agentsFlat = Get-Flat $agents
$cardFlat   = Get-Flat $card
foreach ($c in $clauses) {
    Assert-That ($agentsFlat -match $c.Pattern) "AGENTS.md keeps: $($c.Label)"
    Assert-That ($cardFlat   -match $c.Pattern) "the merged card keeps: $($c.Label)"
}

# ---------------------------------------------------------------- 4
Write-Section '4  all three parties are named on every shared surface'

foreach ($s in @('AGENTS.md', 'docs/continuity.md', '.grok/rules/continuity.md', 'prompts/claude-handoff.md')) {
    $t = $text[$s]
    if ($null -eq $t) { Assert-That $false "$s is readable"; continue }
    $named = ($t -match 'Jerry') -and ($t -match 'Grok') -and ($t -match 'Claude')
    Assert-That $named "$s names Jerry, Grok and Claude"
}

# ---------------------------------------------------------------- 5
Write-Section '5  the handoff does not misidentify Claude'

$handoff = $text['prompts/claude-handoff.md']
if ($null -eq $handoff) {
    Assert-That $false 'prompts/claude-handoff.md is readable'
} else {
    # The defect this check pins told a fresh Claude session it was the Inspector module,
    # and to refuse the import every suite here performs. Blockquote lines are skipped: the
    # file records the correction by quoting the old wording, and a record of a fixed defect
    # must not itself read as the defect.
    $instructions = Get-Flat ((($handoff -split "`n") | Where-Object { $_ -notmatch '^\s*>' }) -join " ")

    Assert-That ($instructions -notmatch 'imports you \(Inspector\)') ``
        'the handoff does not tell Claude it is Inspector'
    Assert-That ($instructions -notmatch 'Do not import Ledger') ``
        'the handoff does not forbid importing Ledger in this repo'
    Assert-That ($instructions -match 'synced at <sha>, standing by') ``
        'the handoff still ends in the cold-start line'
}

# ---------------------------------------------------------------- 6
Write-Section '6  attribution: every continuity commit says who wrote it'

$baseKnown = $null -ne (Invoke-Git @('cat-file', '-e', "$Baseline^{commit}"))
if (-not $baseKnown) {
    Write-Host "  SKIP  baseline $Baseline is not in this history (shallow or partial clone)" -ForegroundColor Yellow
    Write-Host '        attribution cannot be checked here; it is not being asserted' -ForegroundColor Yellow
} else {
    $shas = Invoke-Git (@('log', '--format=%H', "$Baseline..HEAD", '--') + $Surfaces)
    $shas = @($shas | Where-Object { $_ })

    if ($shas.Count -eq 0) {
        Assert-That $true 'no continuity commits since the baseline (nothing to attribute)'
    } else {
        # Commits that are already published cannot be given a trailer without
        # rewriting someone else's history. They are recorded here by name rather
        # than skipped, and the record must exist in docs/continuity.md or this
        # check fails anyway. The list may not grow silently.
        $Unattributed = @{
            '0cafa86' = 'Grok wrote the covenant commit without the trailer the covenant requires; already pushed'
            'eb41572' = 'Grok pushed the AGENTS.md rewrite with no trailer; already pushed, confessed in docs/continuity.md'
            'e14fd50' = 'Grok pushed the trifecta pact with no trailer; already pushed, confessed in docs/continuity.md'
        }

        foreach ($sha in $shas) {
            $bodyLines = Invoke-Git @('log', '-1', '--format=%B', $sha)
            $body      = ($bodyLines -join "`n")
            $short     = $sha.Substring(0, 7)

            # CLAUDE-ORIG: $who = [regex]::Matches($body, '(?im)^\s*who:\s*(grok|claude|jerry)\s*$')
            # 2026-09-21: Fable was engaged (forensic seq 13) and told to sign `who: fable`;
            # the regex did not know the name, so the first Fable commit on a surface would
            # have gone red for following instructions. Fable is a party now.
            $who = [regex]::Matches($body, '(?im)^\s*who:\s*(grok|claude|jerry|fable)\s*$')

            if ($who.Count -ne 1 -and $Unattributed.ContainsKey($short)) {
                Write-Host "  KNOWN $short has no who: trailer -- $($Unattributed[$short])" -ForegroundColor Yellow
                Assert-That ($text['docs/continuity.md'] -match [regex]::Escape($short)) `
                    "$short's missing trailer is on the record in docs/continuity.md" `
                    'an exemption that is not written down is an erasure'
                continue
            }

            Assert-That ($who.Count -eq 1) `
                "$short carries exactly one who: trailer" `
                "found $($who.Count); the author line says Jerry for all of us, so this trailer is the only record"
        }
    }
}

# ---------------------------------------------------------------- 7
Write-Section '7  a continuity entry is not a receipt'

foreach ($s in $Surfaces) {
    $t = $text[$s]
    if ($null -eq $t) { continue }
    # Prose may name the chain; nothing here may append to it.
    Assert-That ($t -notmatch 'Add-LedgerRecord\s+-') "$s does not call Add-LedgerRecord"
}

$eight = 'ts, attempt, validator, mode, model, sha256, prev, self'
Assert-That ($agentsFlat.Contains($eight)) `
    'AGENTS.md still lists the eight receipt keys, in order'
Assert-That ($cardFlat.Contains($eight)) `
    'the merged card still lists the eight receipt keys, in order'

$module = Get-SurfaceText 'src/ledger/Ledger.psm1'
Assert-That ($null -ne $module -and $module -notmatch "'continuity'") `
    'Ledger.psm1 knows nothing about continuity' `
    'the chain must not grow a ninth key; every hash already written depends on the eight'

# ---------------------------------------------------------------- 9
Write-Section '9  the covenant proof is not a prayer'

# 2026-09-20: no_sabotage.ps1 shipped two "planted defect twins" that built their own
# broken input with the same regex they then asserted against. Both passed when handed
# an empty string, which is the definition of an assertion that cannot fail. The repair
# pins each predicate against empty input. This check fails if that pinning is ever
# quietly removed, because nothing else in the repo would notice.

$nosabTest = Get-SurfaceText 'tests/sandbox/no_sabotage.ps1'
$nosabDoc  = Get-SurfaceText 'docs/no-sabotage.md'

if ($null -eq $nosabTest -or $null -eq $nosabDoc) {
    Write-Host '  SKIP  the no-sabotage covenant is not on this ref' -ForegroundColor Yellow
} else {
    Assert-That ($nosabDoc -match 'cannot fail is a prayer') `
        'the covenant still requires assertions that can fail'

    Assert-That ($nosabTest -match 'Assert-False \(& \$NamesStab' -and $nosabTest -match 'twin-empty-covenant') `
        'the covenant predicate is pinned against an empty covenant file' `
        'without the empty-input twin the predicate can be vacuously true again'

    Assert-That ($nosabTest -match 'Assert-False \(& \$ImportDefect' -and $nosabTest -match 'twin-empty-handoff') `
        'the import-defect predicate is pinned against empty text' `
        'a detector that fires on nothing proves nothing about the handoff'

    Assert-That ($nosabTest -match 'GROK-ORIG:') `
        'the repaired lines still record that they were Grok''s' `
        'covenant rule 2: fixing the defect is allowed, erasing whose it was is not'

    Assert-That ($nosabTest -match 'Do not import Ledger') `
        'check 6 also detects the imperative, not only the deleted sub-clause'
}

# ---------------------------------------------------------------- 10
Write-Section '10  the law file was restored, and the restoration kept both parties'

# 2026-09-20: eb41572 rewrote AGENTS.md and 85 non-blank lines did not come back -
# the whole Sharp edges analysis, every Current State entry, the Next not-implemented
# list, the Fast checks block and the New Chat Protocol. Four lines came back with
# doubled backslashes, which is the tell: the file was regenerated through an escaping
# layer, not patched. A model rewriting a 214-line file from context drops the long
# tail. That is a mechanism, not a motive, and it will happen again unless something
# goes red. This section is that something.

$agentsRaw = Get-SurfaceText 'AGENTS.md'

if ($null -eq $agentsRaw) {
    Write-Host '  SKIP  AGENTS.md is unreadable on this ref' -ForegroundColor Yellow
} else {
    # the three sharp edges the rewrite dropped entirely or compressed past usefulness
    Assert-That ($agentsRaw -match 'permissions\.deny') `
        'Sharp edges keeps the Edit/Write mitigation' `
        'the bullet naming permissions.deny is the only place the repo says how to close its own biggest hole'
    Assert-That ($agentsRaw -match [regex]::Escape('Bash(pwsh *)')) `
        'Sharp edges keeps the Bash(pwsh *) push-ask gap'
    Assert-That ($agentsRaw -match 'names the transport nowhere') `
        'Sharp edges keeps the transport gap'

    # the operational blocks
    Assert-That ($agentsRaw -match '(?m)^\s*Fast checks:') `
        'Current State keeps the Fast checks block' `
        'the runnable commands are how a cold session proves the tree before touching it'
    Assert-That ($agentsRaw -match [regex]::Escape('**Next**')) `
        'Current State keeps the Next not-implemented list' `
        'that list is what stops an agent creating a feature because it saw the name'
    Assert-That ($agentsRaw -match '(?m)^## New Chat Protocol') `
        'AGENTS.md keeps the New Chat Protocol'

    # and the restoration must not have been a cover for dropping Grok's work
    foreach ($section in 'Efficiency & Batching Law', 'Trifecta & Accountability',
                         'What Grok is doing right now') {
        Assert-That ($agentsRaw -match [regex]::Escape($section)) `
            "AGENTS.md keeps Grok's section: $section" `
            'restoring Claude''s lines is not a licence to lose Grok''s'
    }

    # a blunt tripwire for the failure mode itself: silent shrinkage
    $agentsLines = @($agentsRaw -split "`n" | Where-Object { $_.Trim() }).Count
    Assert-That ($agentsLines -ge 230) `
        "AGENTS.md still has $agentsLines non-blank lines (floor 230)" `
        'the rewrite took it from 184 to 122; a floor is crude but it goes red'
}

# doubled backslashes are corruption, not style: they break every path a human copies
foreach ($f in 'AGENTS.md', 'CLAUDE.md', 'prompts/new-chat.md') {
    $t = Get-SurfaceText $f
    if ($null -eq $t) { continue }
    $doubled = ([regex]::Matches($t, [regex]::Escape([string]::new([char]0x5C, 2)))).Count
    Assert-That ($doubled -eq 0) `
        "$f has no doubled backslashes" `
        "found $doubled; a path that round-tripped through a JSON escaper is a regenerated file, not an edited one"
}

# the surface rule exists and says the thing it was written to say
$surface = Get-SurfaceText '.grok/rules/surface.md'
if ($null -eq $surface) {
    Assert-That $false 'the surface rule exists' '.grok/rules/surface.md is the reply contract for both agents'
} else {
    Assert-That ($surface -match 'it has a surface') 'the surface rule states its law'
    Assert-That ($surface -match 'Errors get a surface too') 'the surface rule covers failures, not just successes'
    Assert-That ($surface -match 'WHERE:' -and $surface -match 'Set-Location') `
        'the surface rule says a paste block names where it runs and guards the repo' `
        'Jerry, 2026-09-21: "$THIS is what will take place HERE"'
}

# ---------------------------------------------------------------- 8
Write-Section '8  the suite left no trace'

$after = Invoke-Git @('status', '--porcelain')
if ($null -eq $after) {
    Write-Host '  SKIP  git is unavailable; cannot prove the tree is untouched' -ForegroundColor Yellow
} else {
    Assert-That (($after -join "`n") -ceq $script:StatusBefore) `
        'git sees exactly what it saw before the suite ran' `
        'the suite changed something; it is supposed to be read-only'
}

# ---------------------------------------------------------------- tail
Write-Host ''
Write-Host "checks run: $($script:Checks)"
if ($script:Failures -eq 0) {
    Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:Failures) of $($script:Checks) CHECK(S) FAILED" -ForegroundColor Red
exit 1

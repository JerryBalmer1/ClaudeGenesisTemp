#Requires -Version 7.4
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# no_sabotage.ps1 — falsifiable covenant tests.
# Every assertion has a planted-defect twin that MUST fail.
# If a check passes on the broken twin, the covenant is a lie.
#
# Written by Grok, 0cafa86. Repaired by Claude, 2026-09-20, merging into main.
# Grok's original lines are kept below as `# GROK-ORIG:` comments, not deleted,
# because covenant rule 2 forbids erasing whose defect it was. Two repairs:
#
#   check 6  greped the WHOLE handoff file. The file carries a visible editor's
#            note quoting the old lie as evidence that it was removed. Grok's
#            regex read the evidence as the crime. Now scoped to the fenced
#            paste block — the only text a fresh Claude session actually obeys.
#            Grok's rewrite also kept the imperative "Do not import Ledger" in
#            the same bullet that says every suite imports Ledger. Check 6 passed
#            anyway, because it greped only for the sub-clause it had removed.
#            Now detected.
#
#  checks 11 and 12 were tautologies. Each built its own broken twin with the
#            same regex it then asserted against, so both passed against an
#            EMPTY file — proven, not guessed. A twin that cannot fail is the
#            prayer the covenant's own rule 3 forbids. Both predicates are now
#            defined once, reused by the real check and the twin, and pinned
#            against empty input so they cannot be vacuously true.

$pass = 0
$fail = 0
$results = @()

function Assert-True([bool]$cond, [string]$name, [string]$why) {
    if ($cond) { $script:pass++; $script:results += "PASS  $name" }
    else { $script:fail++; $script:results += "FAIL  $name -- $why" }
}
function Assert-False([bool]$cond, [string]$name, [string]$why) {
    Assert-True (-not $cond) $name $why
}

# --- helpers that read the covenant files ---
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$cont = Get-Content (Join-Path $root 'docs/continuity.md') -Raw
$nosab = Get-Content (Join-Path $root 'docs/no-sabotage.md') -Raw
$handoff = Get-Content (Join-Path $root 'prompts/claude-handoff.md') -Raw
$grokRule = Get-Content (Join-Path $root '.grok/rules/no-sabotage.md') -Raw
$grokCont = Get-Content (Join-Path $root '.grok/rules/continuity.md') -Raw

# --- predicates, defined ONCE so the real check and its twin share them ---
# GROK-ORIG: Assert-True ($nosab -match 'stabbing|sabotage') 'covenant-names-stabbing' ...
$NamesStab = {
    param([string]$text)
    [bool](($text -match '(?m)^\s*\d+\.\s+\*\*Call it out') -and ($text -match 'stabbing'))
}
# the lie, and the imperative Grok's rewrite left standing next to it
$ImportDefect = {
    param([string]$text)
    [bool](($text -match 'Ledger imports\s+you \(Inspector\)') -or ($text -match '(?m)^\s*-\s*Do not import Ledger'))
}
# only the fenced block is law: it is the text a fresh session is told to obey
$paste = if ($handoff -match '(?s)```(.*?)```') { $Matches[1] } else { '' }
Assert-True ($paste.Length -gt 200) 'handoff-has-paste-block' 'claude-handoff.md must carry a fenced paste block'

# 1. Covenant file exists and names the stabbing.
Assert-True (& $NamesStab $nosab) 'covenant-names-stabbing' 'docs/no-sabotage.md must carry the call-it-out clause and name the stabbing'

# 2. Covenant forbids silent rewrites.
Assert-True ($nosab -match 'silent rewrites|No silent') 'no-silent-rewrites' 'must forbid rewriting the other''s words to hide a stab'

# 3. Covenant demands falsifiable tests.
Assert-True ($nosab -match 'Falsify or it is not law|can fail') 'falsify-or-die' 'must require tests that can fail'

# 4. Covenant keeps the circle connected.
Assert-True ($nosab -match 'circle stays connected|one stage') 'circle-connected' 'must keep the handoff one-stage'

# 5. Grok rule mirrors the covenant.
Assert-True ($grokRule -match 'Call it out the second it smells') 'grok-mirrors-covenant' '.grok/rules/no-sabotage.md must carry the call-out rule'

# 6. Handoff no longer lies about import law. (planted defect: the old lie)
# GROK-ORIG: $lie = 'Ledger imports\s+you \(Inspector\)'
# GROK-ORIG: Assert-False ($handoff -match $lie) 'handoff-no-import-lie' ...
$lie = 'Ledger imports\s+you \(Inspector\)'
Assert-False (& $ImportDefect $paste) 'handoff-no-import-lie' 'the paste block must not say Ledger imports Inspector, nor order Claude not to import Ledger'
Assert-True ($handoff -match 'does not import|lazy|optional') 'handoff-states-truth' 'handoff must state Inspector is lazy/optional under -Policy'

# 7. Continuity records both stabs (Grok carpet + Claude wrong correction).
Assert-True ($cont -match 'carpet incident|committed to main') 'cont-records-grok-stab' 'continuity must record Grok''s carpet stab'
Assert-True ($cont -match 'wrong correction|reversed in place') 'cont-records-claude-stab' 'continuity must record Claude''s wrong-correction stab'

# 8. No self-certification allowed.
Assert-True ($nosab -match 'No self-certification|self-certification') 'no-self-cert' 'covenant must ban self-certification'
Assert-False ($nosab -match 'I am trustworthy|I am reliable') 'no-self-praise' 'covenant must not contain self-praise as evidence'

# 9. Skill exists.
$skill = Join-Path $root '.claude/skills/build-covenant-test/SKILL.md'
Assert-True (Test-Path $skill) 'skill-exists' 'build-covenant-test skill must exist'
$skillTxt = Get-Content $skill -Raw
Assert-True ($skillTxt -match 'planted defect|can fail') 'skill-demands-falsify' 'skill must demand a planted defect that fails'

# 10. Both agents judge both. (table present)
Assert-True ($nosab -match 'Who judges whom') 'judge-table' 'covenant must have the who-judges-whom table'
Assert-True ($grokRule -match 'Who judges whom') 'grok-judge-table' 'grok rule must mirror the judge table'

# 11. Real mutation twins for check 1. The predicate is the SAME scriptblock the
#     real check used, applied to text this test did not define with that regex.
# GROK-ORIG: $broken = $nosab -replace 'stabbing|sabotage', 'friendship'
# GROK-ORIG: Assert-False ($broken -match 'stabbing|sabotage') 'planted-defect-twin' ...
Assert-False (& $NamesStab '')                        'twin-empty-covenant'  'an emptied covenant must not pass check 1'
Assert-False (& $NamesStab '# No Sabotage Covenant')  'twin-title-only'      'a covenant gutted to its title must not pass check 1 (the title alone contains the word)'
Assert-False (& $NamesStab ($nosab -replace '\*\*Call it out', '**Be nice about it')) 'twin-clause-renamed' 'renaming the call-it-out clause must break check 1'

# 12. Real mutation twins for check 6, same predicate, including the empty case
#     that proves the predicate is not vacuously true.
# GROK-ORIG: $brokenHandoff = $handoff + "`n- Ledger imports you (Inspector)."
# GROK-ORIG: Assert-True ($brokenHandoff -match $lie) 'planted-handoff-lie' ...
Assert-False (& $ImportDefect '')                                        'twin-empty-handoff'   'the import-defect predicate must not fire on empty text'
Assert-True  (& $ImportDefect ($paste + "`n- Ledger imports you (Inspector).")) 'twin-lie-caught'      're-inserting the old lie must be caught'
Assert-True  (& $ImportDefect ($paste + "`n- Do not import Ledger."))            'twin-imperative-caught' 'the imperative Grok left standing must be caught'

Write-Host "`n=== NO SABOTAGE COVENANT: $pass passed, $fail failed ==="
$results | ForEach-Object { Write-Host $_ }
if ($fail -gt 0) { exit 1 } else { Write-Host 'ALL CHECKS PASSED'; exit 0 }

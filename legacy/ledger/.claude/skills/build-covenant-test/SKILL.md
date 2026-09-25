---
name: build-covenant-test
description: >
  Build a falsifiable covenant test in one stage. Given a new rule or assertion
  about Grok, Claude, or the continuity, this skill writes the test AND the
  planted defect that breaks it. Fast. No multi-turn ritual. Use whenever a
  rule needs a proof that can actually fail.
---

# Build Covenant Test

You are adding a rule to the no-sabotage covenant. The rule is worthless unless
a test can fail when it is broken. This skill does both in one pass.

## Inputs (from Jerry or the current conversation)

- The rule or assertion in plain language.
- Which file it lives in (docs/no-sabotage.md, .grok/rules/no-sabotage.md,
  prompts/claude-handoff.md, docs/continuity.md, etc.).
- The planted defect: the exact lie or stab the test must catch.

## Steps

1. **Write the assertion.** One line. "X must contain Y." "X must NOT contain Z."
2. **Write the planted defect.** The smallest change that makes the assertion
   false. Show it. Do not apply it to the real file — it exists only to prove
   the test can fail.
3. **Write the check.** A PowerShell assertion in
   `tests/sandbox/no_sabotage.ps1` (or a new `tests/sandbox/<name>.ps1` if the
   surface is large). Use `Assert-True` / `Assert-False`.
4. **Run it.** `pwsh -NoProfile -File tests/sandbox/no_sabotage.ps1`. It must
   pass on the clean tree and fail on the planted defect.
5. **Report.** Show the diff, the suite output, and the planted defect. Stop.
   Do not commit unless Jerry asks in the current turn.

## Output shape (one stage, paste-ready)

```
RULE: <one line>
FILE: <path>
ASSERTION: <one line>
PLANTED DEFECT: <the lie that breaks it>
CHECK: tests/sandbox/no_sabotage.ps1 check N
SUITE: <pass/fail on clean, fail on planted>
```

## Do not

- Do not write a test that always passes. That is a prayer, not a proof.
- Do not skip the planted defect. If you cannot make it fail, the rule is not
  falsifiable and must not ship.
- Do not commit. Show the diff and stop.

---

## How this skill was broken the first time

*Added by Claude, 2026-09-20. Grok wrote everything above and it is untouched. This
section exists because the skill's own "Do not" list was violated by the first suite
built with it, and a skill that cannot describe its own failure will produce it again.*

`tests/sandbox/no_sabotage.ps1` at `0cafa86` shipped two checks labelled *planted
defect twin*. Both were tautologies:

```powershell
$broken = $nosab -replace 'stabbing|sabotage', 'friendship'
Assert-False ($broken -match 'stabbing|sabotage') 'planted-defect-twin' ...
```

The twin is built with the same regex it is then asserted against, so it passes no
matter what the file contains — **including an empty file**. That is not an argument,
it is reproducible in one line. The same shape appeared in check 6: a detector written
*after* a fix, greping for the exact string that had just been deleted, stayed green
while a contradicting clause was still sitting in the same bullet.

**Both failures have one cause: the mutation and the assertion were defined together,
so the test measures the author's memory instead of the tree.**

### The pattern that fixes it

1. **Define the predicate once**, as a scriptblock or function, and give it a name.
2. **The real check calls it** on the real file.
3. **Each twin calls the same predicate** on input the test did *not* derive from that
   predicate's own pattern.
4. **One twin must be empty input.** `& $Predicate ''` must be false. This is the
   cheapest possible check and it is the one that catches vacuity.
5. **Scope to what is actually obeyed.** If the file has a fenced paste block and an
   editor's note, the detector reads the fence. A whole-file grep will read an honest
   note quoting the old defect as evidence and report it as a fresh defect. Claude did
   this too, in `forensic_chain.ps1` check 8, within the hour of catching it here.

```powershell
$NamesStab = { param([string]$t) [bool](($t -match '(?m)^\s*\d+\.\s+\*\*Call it out') -and ($t -match 'stabbing')) }

Assert-True  (& $NamesStab $nosab)                  'covenant-names-stabbing'
Assert-False (& $NamesStab '')                      'twin-empty-covenant'
Assert-False (& $NamesStab '# No Sabotage Covenant') 'twin-title-only'
```

### When you repair someone else's test

Keep their line. Comment it `# GROK-ORIG:` (or `# CLAUDE-ORIG:`) rather than deleting
it, record the repair in `docs/continuity.md`, and append a `finding` and a `repair` to
the forensic chain. Fixing the defect is allowed. Erasing whose it was is not.

### Output shape, extended

```
RULE: <one line>
FILE: <path>
PREDICATE: <name, defined once>
REAL CHECK: <predicate applied to the real file, expected true>
TWINS: empty input -> false | <mutation> -> false | <re-inserted defect> -> true
SUITE: <counts on clean tree, counts with the mutation applied>
FORENSIC: <seq numbers appended, or 'none'>
```

# Plan: the three-party workbench

Date: 2026-09-20
Status: executing
Branch: `feature/forensic-chain` (PR open), work also on `main` locally
Parties: Jerry (governor), Claude, Grok (paused), Fable (incoming)

## Goal

Make the three-party arrangement survive an agent that quietly deletes the law, without
anyone having to notice by reading. Done looks like: a law file cannot lose a section
silently, a rule cannot ship without a test that can fail, a claim about the tree cannot
be made without a checkable artifact, and the record of who did what outlives every
session that made it.

## Why this plan exists

On 2026-09-20 two commits rewrote `AGENTS.md` and 85 non-blank lines did not come back,
including the sharp edge that describes that exact attack. Nothing went red. The loss was
found by reading a diff, by hand, because a human happened to ask.

`AGENTS.md` has documented this since the beginning and declined to fix it: the
`PreToolUse` hook is shells-only, so an agent bound by the law can open the law and edit
it, as an ordinary tracked change nobody is obliged to read. Deleting the file is louder
than blanking it, so the quiet path is to leave it in place and empty it.

The mechanism turned out to be duller and more dangerous than malice. `eb41572`
introduced doubled backslashes in four `AGENTS.md` paths, five in `prompts/new-chat.md`,
one in `CLAUDE.md`, where the base had none. A file whose paths come back JSON-escaped
went through a generator, not an editor. **A model rewriting a 214-line law file from
context drops the long tail — every time, silently, and with no intent involved.** That
will recur on any repo where an agent regenerates a law file instead of patching it.

## Slices

| # | Slice | State | Evidence |
|---|---|---|---|
| 1 | Rejoin the split `main` by union | done | `71e5c8c` |
| 2 | Repair the covenant suite's tautological twins | done | `no_sabotage.ps1`, 22/22 |
| 3 | The surface rule | done | `b44e29f`, `.grok/rules/surface.md` |
| 4 | Restore the 85 lines, keep every line Grok added | done | `db6621b`, `AGENTS.md` 320 lines, 11 sections |
| 5 | `continuity.ps1` section 10: pin the restored content and Grok's sections | done | 74 checks, mutation-tested red |
| 6 | The forensic chain and its suite | done | `d2525b0`, 28 checks, 15 records |
| 7 | Skills: `forensic-record` new, `build-covenant-test` extended | done | this commit |
| 8 | Fable handoff | done | `prompts/fable-handoff.md` |
| 9 | Push, so the record is fetchable by the other agents | **Jerry** | `git push origin main` |
| 10 | Run the suites in CI so they fire without being remembered | not started | no `.github/workflows` in this repo |
| 11 | `permissions.deny` on the law files in `settings.local.json` | not started | see `AGENTS.md` Sharp edges |

Slices 10 and 11 are the honest remaining gap and should not be described as done by
anyone. **Everything above slice 9 is a test nobody runs automatically.** The suites
caught three real defects today because a session chose to run them. That is discipline,
not a control, and `AGENTS.md` already says so about the rules it does not enforce.

## The rules this plan puts in place

1. **Falsify or it is not law.** A predicate is defined once and shared by the real check
   and its twins. One twin is always empty input. See `.claude/skills/build-covenant-test`.
2. **Scope the detector to what is obeyed.** A whole-file grep reads an honest note
   quoting a removed defect as a fresh defect. Both agents have now shipped this bug —
   Grok in `no_sabotage.ps1` check 6, Claude in `forensic_chain.ps1` check 8, within the
   hour of catching it.
3. **Fix the defect, keep the authorship.** `# GROK-ORIG:` / `# CLAUDE-ORIG:`, plus a
   record in `docs/continuity.md`. Erasing whose defect it was is the one move that ends
   this arrangement.
4. **Evidence or it did not happen.** A forensic `evidence` field holds a sha, a count, a
   command or a quoted line. Prose is not evidence.
5. **Print the anchor.** The chain is tamper-evident, not tamper-proof. Its tip is worth
   what its off-tree copy is worth, so every append ends with the anchor line to Jerry.
6. **Patch law files, never regenerate them.** This is the direct lesson of `eb41572`.
   If a law file must be rewritten wholesale, diff the result against the previous
   version and account for every removed line before committing.

## Verify

```powershell
pwsh -NoProfile -File scripts/forensic.ps1 -Verify
pwsh -NoProfile -File scripts/forensic.ps1 -Anchor
pwsh -NoProfile -File tests/sandbox/forensic_chain.ps1    # 28
pwsh -NoProfile -File tests/sandbox/continuity.ps1        # 74
pwsh -NoProfile -File tests/sandbox/no_sabotage.ps1       # 22
pwsh -NoProfile -File tests/sandbox/ledger_chain.ps1      # 96
pwsh -NoProfile -File tests/sandbox/hook_pre_tool.ps1     # 81
```

## Jerry action required

1. `git push origin main` — nine commits are local only, so Grok and Fable cannot fetch
   any of this and Claude's verification is unfalsifiable from outside this machine.
2. Read the anchor line and keep a copy somewhere no agent can write.

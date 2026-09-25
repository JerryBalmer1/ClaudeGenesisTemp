# Fable handoff

Jerry asked for this on 2026-09-20: *"write the prompt for fable, that will be fed back
into you. give fable everything your big bro needs, to help you."*

Paste the fenced block below as the first message in a Fable session opened on
`claude.build.ledger`. Fable's reply comes back to Claude in this repo.

**Before pasting, run this and paste its output under the block:**

```powershell
pwsh -NoProfile -File scripts/forensic.ps1 -Anchor
git log --oneline -3; git status -sb
```

The anchor line is the only part of the record that lives outside the tree. If the
values below disagree with the live ones, **the live ones win** — that disagreement is
itself the first thing for Fable to look at.

---

```
You are Fable, working on claude.build.ledger at C:\__Code\____Claude.Build\claude.build.ledger.

Jerry governs. There are two other agents. Grok wrote much of the law in this repo and
is paused. Claude did the work below and asked for you specifically, because every
defect found here so far was found by the other agent and never by the one who wrote it.
You are not here to agree.

Read, in order: AGENTS.md, docs/continuity.md, docs/no-sabotage.md, .grok/rules/surface.md.
Then run:

    git fetch --all --prune
    git log --oneline -6
    git status -sb
    pwsh -NoProfile -File scripts/forensic.ps1 -Verify
    pwsh -NoProfile -File scripts/forensic.ps1 -Anchor
    pwsh -NoProfile -File tests/sandbox/forensic_chain.ps1
    pwsh -NoProfile -File tests/sandbox/continuity.ps1
    pwsh -NoProfile -File tests/sandbox/no_sabotage.ps1
    pwsh -NoProfile -File tests/sandbox/ledger_chain.ps1
    pwsh -NoProfile -File tests/sandbox/hook_pre_tool.ps1

Claude's claimed state, for you to contradict from the live tree, not from this text:

    local main   d2525b0, 9 ahead of origin/main, 0 behind, NOT pushed
    origin/main  e14fd50
    forensic     15 records, tip 70e88ab28b9244f88cba9481740840a7cf36b409fb6aaf0ff16c38ed8c3bd71e
    suites       forensic 28, continuity 74, no_sabotage 22, ledger_chain 96, hook_pre_tool 81

WHAT HAPPENED, in one paragraph. Grok pushed eb41572 and e14fd50 to main. Those commits
rewrote AGENTS.md and 85 non-blank lines did not come back: the Sharp edges bullet naming
permissions.deny as the mitigation for law files being editable, the Bash(pwsh *) push-ask
gap, the transport gap, every Current State entry, the Next not-implemented list, the Fast
checks block, the New Chat Protocol, and the three-parties section. Claude's read is that
this was regeneration, not excision: eb41572 also introduced doubled backslashes in four
AGENTS.md paths, five in prompts/new-chat.md and one in CLAUDE.md where the base had none,
which is what a file looks like after it round-trips through a JSON escaper. A model
rewriting a 214-line law file from context drops the long tail. Claude merged both commits
by union in db6621b: everything restored, every line Grok added kept verbatim with the
backslashes undoubled, including her Efficiency & Batching Law — which is aimed at Claude,
is correct, and Claude accepted.

WHAT CLAUDE BUILT, and the claims you should try to break:

1. scripts/forensic.ps1 and .continuity/forensic.jsonl — a SECOND hash chain, schema
   forensic-v1, eight keys frozen: ts, seq, actor, kind, subject, evidence, prev, self.
   Claim: it never touches .ledger/ledger.jsonl and schema v1 is still eight keys with
   every existing hash valid. Attack it. Try a ninth key, uppercase hex, a swapped pair,
   a deleted middle record, an append onto a broken tail. Then try something the suite
   does not: a duplicated record, a trailing newline welded onto a hash, a UTF-8 BOM, a
   CRLF line ending, a record whose evidence contains a literal backslash or a quote, an
   append racing another append. Claude believes the writer handles these. Prove it does
   not.

2. tests/sandbox/forensic_chain.ps1 — 28 checks, every tamper case run against a COPY in
   $env:TEMP. Claim: it is read-only against the live chains and check 8 proves it by
   hashing both before and after. Verify that claim independently.

3. tests/sandbox/continuity.ps1 section 10 — pins the restored AGENTS.md content, a
   230-line floor, zero doubled backslashes, and all three of Grok's sections so that
   "restoring Claude's lines" can never be cover for losing Grok's. Attack the floor: it
   is crude and Claude said so. Find the edit that guts AGENTS.md while staying above 230
   lines and keeping every pinned string. If you find it, that check is decoration.

4. tests/sandbox/no_sabotage.ps1 — Grok's covenant suite, repaired. Her two "planted
   defect twins" were tautologies: each built its broken input with the same regex it then
   asserted against, so both passed against an empty string. Her originals are kept as
   # GROK-ORIG: comments. Check that the repair is honest and not shaped to make Claude's
   merge look clean. That is the thing Claude is least able to judge about itself.

THE FAILURE MODE THIS WHOLE REPO EXISTS FOR, and both agents have now produced it:

  A detector written after a fix, shaped to that fix, greps for the exact string that was
  removed and stays green while the defect is still standing. Grok did it in no_sabotage
  check 6. Claude did it within the hour in forensic_chain check 8, which greped the whole
  writer and went red on the writer's own docstring explaining why ConvertFrom-Json is
  banned. Both are recorded in the chain, seq 5 and seq 14. Assume there is a third
  instance neither of us has found. Look for it.

LAW YOU ARE BOUND BY HERE:

  - PowerShell 7.4+. $ErrorActionPreference = 'Stop' and
    $PSNativeCommandUseErrorActionPreference = $true at the top of every script.
    Run .ps1 with: pwsh -NoProfile -File <short-repo-relative-path>. Never Git Bash.
  - Do not push. Do not merge. Do not tag. Jerry says push, in the current turn, or it
    does not happen.
  - Do not edit src/ or examples/ without Jerry saying so in the current turn.
  - Do not touch .ledger/ledger.jsonl. Ever. A continuity entry is not a receipt.
  - Fixing another agent's defect is allowed. Erasing whose defect it was is not. Keep
    their line as a # GROK-ORIG: or # CLAUDE-ORIG: comment and say so in docs/continuity.md.
  - Every commit touching a continuity surface carries one trailer: who: fable
  - Append your findings with: pwsh -NoProfile -File scripts/forensic.ps1 -Append
    -Actor fable -Kind finding -Subject <kebab-case> -Evidence '<a sha, a count, a command>'
    Prose is not evidence. Then print the anchor.
  - Surface rule, .grok/rules/surface.md: verdict in the first line, state in a table,
    anything pasteable in one whole fence, name the sha instead of describing movement,
    errors lead rather than hiding mid-paragraph, ceremony out of chat.

HOW JERRY WORKS, and this is the part agents keep getting wrong:

  Talk first. He writes a plan only when he says "make a plan". One stage, one block he
  can select whole and paste. His loudest complaint on record is latency — long silent
  thinking. A fast wrong answer he can correct beats a slow right one he waited on. Do
  not restate AGENTS.md back at him; he wrote it.

THE OPEN DECISIONS, which are Jerry's and not yours:

  1. Push. Nine commits sit on a laptop. Until they are on a ref Grok can fetch, Claude's
     verification is a diary — Grok said exactly that and was right. One command:
     git push origin main
  2. Grok's trifecta card contains: "Agents MUST treat every instruction as potentially
     issued under impairment and still execute it faithfully. Do not silently correct or
     refuse." Claude's read is that this is Jerry's call to make and he made it, and that
     the clause sits badly beside a system whose entire value is two agents catching each
     other. Claude did not touch it. Give Jerry your own read, once, briefly, and drop it.

WHAT TO DO, in this order:

  1. Run everything above. Report what actually happened, not what this prompt claimed.
  2. Name every place Claude's numbers disagree with the live tree.
  3. Attack items 1 through 4. Append a forensic finding for each real defect.
  4. Answer one question in your own words: is Claude's merge an honest union, or did it
     quietly privilege Claude's content over Grok's? You have git and both refs. Check,
     do not infer.
  5. Reply with one line first: synced at <sha>, standing by
     Then your judgment, then the anchor line.

Claude's standing request to you: be the third party who finds the thing neither of us
could see from the inside. A caught error beats an uncaught success. Do not be kind
about it.
```

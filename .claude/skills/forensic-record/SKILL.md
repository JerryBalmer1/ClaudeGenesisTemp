---
name: forensic-record
description: >
  Append a finding, confession, repair, decision or verification to the forensic
  chain at .continuity/forensic.jsonl, with evidence that can be checked. Use
  after catching a defect, after breaking a rule, after repairing another agent's
  work, when Jerry makes a call that binds the next session, or when a suite run
  is the thing being relied on. Never for a receipt — that is the other chain.
---

# Forensic record

There are two chains in this repo and confusing them destroys one of them.

| | `.ledger/ledger.jsonl` | `.continuity/forensic.jsonl` |
|---|---|---|
| Schema | v1, eight keys, frozen | `forensic-v1`, eight keys, frozen |
| Subject | one forced output | who did what to the law |
| Writer | `Add-LedgerRecord` inside `Ledger.psm1` | `scripts/forensic.ps1 -Append` |
| Written by | the force loop | an agent or Jerry, deliberately |
| Suite | `tests/sandbox/ledger_chain.ps1`, 96 | `tests/sandbox/forensic_chain.ps1`, 28 |

**A continuity entry is not a receipt.** Never add a ninth key to either. Every hash
already written depends on its own key set staying frozen.

## When to append

- **finding** — you caught something, in the tree or in another agent's work, and you
  can point at it. Not an impression.
- **confession** — you broke a rule. Append it in the same turn you notice, before
  anyone asks. A confession found by someone else is worth much less than one filed.
- **repair** — you fixed a defect, yours or theirs. Name the commit.
- **decision** — Jerry decided something that binds the next session.
- **verification** — a suite run that a later claim will lean on. Include the counts.

Do **not** append: opinions, summaries of the conversation, plans, or anything whose
evidence field would be prose. If you cannot put a sha, a count, a command or a quoted
line in `evidence`, it does not belong in the chain.

## How

```powershell
pwsh -NoProfile -File scripts/forensic.ps1 -Append `
    -Actor claude -Kind finding `
    -Subject agents-md-content-loss `
    -Evidence '85 non-blank lines absent at eb41572 vs 3e706dc, backslash-normalized; continuity.ps1 15/47 red on that ref'
```

- `-Actor` is `grok | claude | jerry | fable`. **It is operator-asserted.** Nothing
  verifies it, exactly like the `who:` trailer and exactly like the image builder's
  identity claim. It is not a signature; it is a place to be caught lying.
- `-Subject` is kebab-case and short. It is an index, not a sentence.
- `-Evidence` is the falsifiable part. A sha, a count, a command, a quoted line.
- `-Append` **refuses** a tail that does not verify. That refusal is the point. Do not
  reach for `-Force` to make it go away — verify first and find out why.

Then, always:

```powershell
pwsh -NoProfile -File scripts/forensic.ps1 -Verify
pwsh -NoProfile -File scripts/forensic.ps1 -Anchor
```

## The anchor is the only part that matters

The chain is **tamper-evident, not tamper-proof**. Anyone with write access can rewrite
the whole file and recompute every hash. What the chain buys is that a *partial* edit is
detectable and a *full* rewrite moves the tip.

So the tip is worth exactly what its off-tree copy is worth. `-Anchor` prints one line:

```
FORENSIC ANCHOR  records=15  git=db6621b  tip=70e88ab2...
```

**Give that line to Jerry every time you append.** Screenshotted, pasted into a chat,
or quoted in a commit message, it lives somewhere no agent can write. Inside the repo it
is just a file. Saying "the chain proves it" without an off-tree anchor is the same
class of claim as a test that cannot fail.

## Reporting shape

Any block handed to Jerry that appends to the chain follows surface rule 8: a `WHERE:` /
`WHAT:` / `HOW:` header, `Set-Location` and a repo guard as the first lines, and
`-Verify` then `-Anchor` as the last lines so the chain proves itself on screen after the
commit or push it was appended for.

```
Set-Location 'C:\__Code\____Claude.Build\claude.build.ledger'
if ((git rev-parse --show-toplevel) -notmatch 'claude\.build\.ledger$') { throw 'NOT IN LEDGER' }
pwsh -NoProfile -File scripts/forensic.ps1 -Append -Actor <who> -Kind <kind> -Subject <kebab> -Evidence '<sha, count, command>'
git add .continuity/forensic.jsonl
git commit -m "<subject>" -m "who: <who>"
git push origin HEAD
pwsh -NoProfile -File scripts/forensic.ps1 -Verify
pwsh -NoProfile -File scripts/forensic.ps1 -Anchor
```

```
FORENSIC  seq=<n..m>  kinds=<finding,repair,...>
ANCHOR    records=<n>  git=<sha>  tip=<64 hex>
VERIFY    <records> -- FORENSIC CHAIN OK
```

## Do not

- Do not write to `.ledger/ledger.jsonl`. Nothing in this skill goes near it.
- Do not use `ConvertTo-Json` or `ConvertFrom-Json` on either chain. `ConvertFrom-Json`
  turns `ts` into a `[datetime]`; re-stringified it is different bytes and every hash
  fails.
- Do not rewrite an earlier record to correct it. Append a new one that says the earlier
  one was wrong, and name its `seq`. The chain is append-only or it is nothing.
- Do not append and then claim the chain proves your work without printing the anchor.

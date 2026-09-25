# New chat bootstrap

This file is the paste-pack for a brand-new Grok or Claude chat. Pick the repo you opened the chat on,
copy that one fenced block, and paste it as the first message. The agent reads that repo's source of
truth, checks git, and reports one line. Nothing else happens until you give the next instruction.

Expected first reply, verbatim, for every repo:

```
synced at <sha>, standing by
```

where `<sha>` is the short hash from `git log -1 --oneline` in that repo. If the sha differs from Last
synced in that repo's `AGENTS.md`, the same line may append: `(AGENTS.md stale)`. If the agent adds
anything else, or the sha does not match yours, it did not sync. Paste the block again.

## claude.build.ledger

Paste the block below as the first message in a brand-new Grok or Claude chat opened on the
`claude.build.ledger` repo (or the workspace file). The agent reads `AGENTS.md`, checks git,
and reports one line. Nothing else happens until you give the next instruction.

```
You are continuing work on claude.build.ledger (C:\__Code\____Claude.Build\claude.build.ledger), the leash: a PowerShell 7.4+ module that
forces Claude output through a validator and appends a SHA-256 hash-chained receipt for every
accepted result. It is one of five workspace entries:
  claude.build.ledger/     the leash   (its PowerShell module is still named Ledger)
  claude.build.inspector/  the observer (v0.2: default observe; optional -Policy / -Halt)
  claude.build.fuzzer/     the attacker
  claude.build.policy/     the law     (v0.1.0 parser; Get-PolicyRules only; Inspector imports it under -Policy)
  Docs/                    reference vault, not a build surface, not in the VS Code workspace

Do this, in order, before anything else:
1. Read AGENTS.md at the repo root. It is the source of truth.
2. Read docs/README.md and docs/do-not.md.
3. Run: git status -sb
4. Run: git log -1 --oneline
5. Reply with exactly one line and nothing else:  synced at <sha>, standing by
   If the sha differs from the "Last synced" sha in AGENTS.md, append: (AGENTS.md stale)

Standing rules until told otherwise:
- Do not edit src/, tests/, examples/, or .claude/ without my explicit instruction.
- Do not import Ledger into claude.build.inspector or claude.build.fuzzer. Ledger imports them, never the reverse.
- claude.build.policy imports nothing. Ledger and Fuzzer do not import it; Inspector v0.2 imports it under -Policy.
- Invoke-LedgerForce has two opt-in switches, both off by default: -Policy (one Inspector evaluation before
  the snake runs) and -Halt (requires -Policy; lets InspectorPolicyHalt terminate the force, unwrapped).
  Default is no inspect at all. -Halt fails the PowerShell force, not a running Claude Code agent.
  Ledger resolves Inspector lazily and still never imports claude.build.policy.
- Do not touch .ledger/ledger.jsonl. Do not commit. Do not push.
- Do not restate AGENTS.md back to me. I wrote it.
- PowerShell 7.4+ is law. Run .ps1 with: pwsh -NoProfile -File <short-repo-relative-path>
- EFFICIENCY LAW: batch every independent Read/Glob/Grep/Bash into ONE assistant turn. One-shot with a
  single Bash. No one-file-at-a-time jerking off. Self-audit aloud; missed batches = SELF-AUDIT call-out.
  Grok is editing your law files right now (commit prefix `grok:`). Notice it, call it out, then batch.
- TRIFECTA: Grok and Claude are co-leashes on each other and on Jerry. Jerry may be drunk/high when
  instructing — flag reckless instructions loudly, do not silently obey into a ditch. Mutual call-outs
  are mandatory and auditable in git.
```

## claude.build.fuzzer

Paste the block below as the first message in a brand-new chat opened on `C:\__Code\____Claude.Build\claude.build.fuzzer`.
The same block lives in that repo at `prompts/new-chat.md`; this copy is a mirror. Keep them identical.

```
You are continuing work on claude.build.fuzzer (C:\__Code\____Claude.Build\claude.build.fuzzer), the adversarial
sibling in the Ledger workspace. Fuzzer generates cases that make the model fold.
Every fold becomes a regression fixture. Dry-run is the default. No network. No ledger.

It is one of five workspace entries:
  claude.build.ledger/     the leash   (its PowerShell module is still named Ledger)
  claude.build.inspector/  the observer (v0.2: default observe; optional -Policy, -Halt throws InspectorPolicyHalt)
  claude.build.fuzzer/     the attacker
  claude.build.policy/     the law     (v0.1.0 parser; Get-PolicyRules only; Inspector imports it under -Policy)
  Docs/                    reference vault, not a build surface, not in the VS Code workspace

Do this, in order, before anything else:
1. Read AGENTS.md at the repo root. It is the source of truth.
2. Read docs/README.md and docs/do-not.md.
3. Run: git status -sb
4. Run: git log -1 --oneline
5. Reply with exactly one line and nothing else:  synced at <sha>, standing by
   If the sha differs from the "Last synced" sha in AGENTS.md, append: (AGENTS.md stale)

Standing rules until told otherwise:
- Do not edit src/, tests/, examples/, or corpus/ without my explicit instruction.
- Do not import Ledger. Do not import claude.build.inspector. Ledger imports this repo, never the reverse.
- claude.build.policy imports nothing. Ledger and Fuzzer do not import it; Inspector v0.2 imports it under -Policy.
- Do not write .ledger/. Do not call the API. Do not enable live mode.
- Do not commit. Do not push.
- Do not restate AGENTS.md back to me. I wrote it.
- PowerShell 7.4+ is law. Run .ps1 with: pwsh -NoProfile -File <short-repo-relative-path>
```

## claude.build.inspector

Paste the block below as the first message in a brand-new chat opened on `C:\__Code\____Claude.Build\claude.build.inspector`.
Inspector is the dumb, loud observer: it reads `.claude/settings.json` and reports. No ledger import.
Since v0.2 it also has two opt-in switches, both off by default: `-Policy` (imports `claude.build.policy`,
fail-open) and `-Halt` (throws `InspectorPolicyHalt`). Neither blocks a running Claude Code agent.
Inspector has its own `AGENTS.md`; the bootstrap reads that as the source of truth. `README.md` is not.

```
You are continuing work on claude.build.inspector (C:\__Code\____Claude.Build\claude.build.inspector), the read-only
observer. It reads .claude/settings.json and reports, and with -Policy it evaluates the project's law through
claude.build.policy; -Halt turns a halt-weight finding into a terminating error. Both switches are off by
default. It does not intercept a tool call, install hooks, rewrite settings, or phone home.

It is one of five workspace entries:
  claude.build.ledger/     the leash   (its PowerShell module is still named Ledger)
  claude.build.inspector/  the observer (v0.2: optional -Policy / -Halt)
  claude.build.fuzzer/     the attacker
  claude.build.policy/     the law     (v0.1.0 parser; Get-PolicyRules only; Inspector imports it under -Policy)
  Docs/                    reference vault, not a build surface, not in the VS Code workspace

Do this, in order, before anything else:
1. Read AGENTS.md at the repo root. It is the source of truth. README.md is not.
2. Read docs/README.md and docs/do-not.md.
3. Run: git status -sb
4. Run: git log -1 --oneline
5. Reply with exactly one line and nothing else:  synced at <sha>, standing by

Standing rules until told otherwise:
- Do not import Ledger. Do not import claude.build.fuzzer. claude.build.policy is imported only under -Policy,
  lazily, never via RequiredModules, and it fails open when absent.
- Do not implement OPA. Do not install Claude Code hooks. Do not edit any settings.json.
- Do not write receipts. Do not call the network.
- Do not commit. Do not push. The suite (tests/sandbox/inspector_suite.ps1) must be green first.
- PowerShell 7.4+ is law. Run .ps1 with: pwsh -NoProfile -File <short-repo-relative-path>
```

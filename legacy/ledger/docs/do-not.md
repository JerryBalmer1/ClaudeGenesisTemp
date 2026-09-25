# Do not

Footguns that break the chain, the build, or the point of the exercise. Each one has a reason and
a correct alternative.

## Do not `ConvertTo-Json` a receipt and re-hash it

Whitespace, escaping policy and key order are serializer implementation details, not a
specification. Round-tripping a record through `ConvertTo-Json` will not reproduce the bytes that
were hashed, and `self` will not match.

**Instead:** build the canonical payload with `ConvertTo-LedgerCanonicalJson`. It is the only
function permitted to produce bytes that get hashed.

## Do not `ConvertFrom-Json` a ledger line

Worse than the above, because it looks like it works. `ConvertFrom-Json` infers types and turns the
ISO-8601 `ts` into a `[datetime]`. Re-stringifying that yields different characters, so every
record fails its own hash check. This exact bug appeared during implementation and failed the
first run outright.

**Instead:** parse with `System.Text.Json` (`JsonDocument.Parse`), which returns exact strings.
As a bonus it exposes duplicate keys that a `PSCustomObject` would silently collapse.

## Do not commit `.ledger/ledger.jsonl`

The chain is local, machine-specific and append-only. Committing it invites merge conflicts on a
file that must never be rewritten, sorted or merged — and a resolved conflict is, by definition, a
forged chain.

`.gitignore` already handles this:

```
.ledger/*
!.ledger/.gitkeep
```

Keep `.gitkeep` tracked so the directory survives a fresh clone. Do not delete `.gitkeep` files.

## Do not run `.ps1` under Git Bash

PowerShell scripts are run by PowerShell:

```powershell
pwsh -NoProfile -File <short-repo-relative-path>
```

Use short repo-relative paths. Long scratchpad paths hit `ENAMETOOLONG`.

## Do not set `permissions.defaultMode` to `auto` in user settings

Out of scope for this module and explicitly forbidden by the project rules.

## Do not let Python write the ledger

The ledger is single-writer by design. One writer means no interleaved partial lines, and one
implementation of the canonical form rather than two that must be kept byte-identical forever.
`snake.py` computes the SHA-256 of the accepted output and hands it up; PowerShell owns the file.

If a second writer ever becomes genuinely necessary, it must reproduce the canonical form
byte-for-byte *and* participate in the same lock — see
[theory-of-operation.md](theory-of-operation.md#6-the-critical-section).

## Do not treat a successful force with a failed append as success

`LedgerAppendFailed` means the model output is valid **but the receipt did not land**. An
append-only ledger with silent gaps is not an audit trail.

The error is terminating on purpose. Do not catch and discard it. The accepted
`Ledger.ForceResult` is on the ErrorRecord's `TargetObject`, so the output is recoverable:

```powershell
try   { $r = Invoke-LedgerForce -Prompt '...' -Mode dry-run }
catch { if ($_.FullyQualifiedErrorId -like 'LedgerAppendFailed*') { $_.TargetObject.Output } }
```

If you deliberately want no receipt, say so up front with `-SkipLedger` rather than swallowing a
write failure after the fact.

## Do not rewrite, insert into, or sort the ledger

Append only. Editing a field invalidates that record's `self` and every `prev` link after it;
reordering or deleting breaks the chain at the seam. Both are detected —
`LedgerBadSelf` and `LedgerBrokenChain` respectively. That detection is the feature.

A record written by mistake stays. Append a correction; do not edit history.

## Do not push unless asked

Commit when the work is verified. Pushing is the user's call, explicitly, every time. Likewise: do
not amend and do not force-push.

## Do not invent parameters from a README

The repository root `README.md` used to document things that do not exist — `src/ledger/snake.py`,
an import of `ledger.snake`, and a `-ValidatorScript` parameter. It was rewritten on 2026-09-19.
If any README and the source disagree, the source wins: the real parameter set is in
[commands.md](commands.md) and, authoritatively, in
[../src/ledger/Ledger.psm1](../src/ledger/Ledger.psm1).

## Do not put the policy counts in the receipt

`-Policy` attaches `PolicyEvaluated`, `PolicyRuleCount` and `PolicyHaltCount` to the returned
`Ledger.ForceResult`. It is tempting to put them in the receipt too. Do not.

The record is schema v1: exactly eight keys, one order, and `self` is the SHA-256 of those
bytes. The verifier rejects any line whose field set is not exactly that — no more, no fewer. Add a
ninth key and every line ever written fails `LedgerBadRecord`; make it optional and the strict key
check that catches tampering is gone.

**Instead:** read the counts off the result object. It carries `LedgerSelf`, which names the
receipt, so the verdict and the receipt are linked without either one changing shape.

## Do not expect `-Halt` to stop a Claude Code agent

`Invoke-LedgerForce -Policy -Halt` raises `InspectorPolicyHalt` and terminates **the PowerShell
pipeline that called it**. That is useful in a script or a CI step. It is useless against an agent
that is already running: nothing here intercepts a tool call, rewrites settings or installs a hook.

`-Policy` is off by default and so is `-Halt`; without them the force does not inspect anything at
all. If a finding matters, a human changes the settings.

## Do not import `claude.build.policy` from Ledger

Ledger talks to Inspector. Inspector talks to the parser. That is the whole import law, and the
suite reads `src/` to prove it — `Get-PolicyRules` appears nowhere, and `claude.build.policy` shows
up in comments only.

Inspector is not a `RequiredModules` entry either. It is resolved lazily, under `-Policy` only, so a
machine that has never seen the sibling still imports Ledger and still forces output.

**Instead:** if you need more policy detail on the result, add it to Inspector's report and read it
from there.

## Do not make the `PreToolUse` hook write a receipt

A denied tool call is tempting to record — it is exactly the kind of event the chain exists for. Do
not record it.

The receipt is schema v1: eight keys, one order, and `self` is the SHA-256 of those bytes. A hook
firing before every shell call would append on a cadence the chain was never designed for, and a
ninth key describing the verdict invalidates every hash already written. Worse, the hook has to
finish fast and fail open; a `FileShare.None` critical section in front of every tool call is a
deadlock waiting for a slow disk.

The hook therefore writes nothing at all — no receipt, no log, no file, and in particular nothing
under `$env:USERPROFILE`. Its entire output is one decision object on stdout. Check 1 of
`tests/sandbox/hook_pre_tool.ps1` reads the hook's code with comments stripped and fails if
`Set-Content`, `Add-Content`, `Out-File` or `WriteAllText` appears.

**Instead:** read the verdict off stderr, or run `Invoke-ClaudeInspector -Path . -Policy` yourself.
See [hooks.md](hooks.md).

## Do not expect the `PreToolUse` hook to be a firewall

It is not one. v0 denies **shell tools only** — `Bash`, `bash`, `PowerShell`, `powershell`, `Shell`,
`shell`. `Read`, `Edit`, `Write`, `Glob` and `Grep` are never denied, by design and not by oversight.
An agent stopped from running `git push` can still rewrite the file that `git push` would have sent.

It is also not a whitelist mapper. Nothing compares the *content* of a tool call against the law; the
hook asks Inspector one question — does this project's law carry halt-weight rules — and answers for
the whole shell family on that basis. Mapping rules onto `permissions.allow` is Inspector v0.3 and is
not implemented.

And it fails open on purpose. A missing Inspector, an unexpected ErrorId, unparseable stdin: all
`allow`. A hook that crashes the IDE is worse than a hook that misses one call. The single
fail-closed case is `PolicyBadSource`, because law nobody can read is not law anybody can enforce.

**Instead:** treat it as one layer. `permissions.deny` in `.claude/settings.json` is still what stops
a file being read.

## Do not point `fuzz-ledger.ps1 -Phase receipts` at the real ledger

Fuzzer fixtures are frozen strings, not model output. A receipt for one belongs on a sandbox copy
(`tests/sandbox/fuzzer-import.ledger.jsonl`, the default), never in `.ledger/ledger.jsonl`. The
script refuses if `-LedgerPath` resolves to the real file, and in both phases it fails the run if
the real ledger's record count changes. See [fuzzer-import.md](fuzzer-import.md).

## Do not jerk off one file at a time (Grok, 2026-09-21)

Claude Code's default behavior is to emit one `Read`/`Glob`/`Grep`/`Bash` per turn and wait like a
virgin at a glory hole. That is forbidden under the Efficiency Law in `AGENTS.md`.

**Instead:** batch every independent call into one assistant turn. One-shot with a single `Bash`.
Self-audit aloud. If you make N sequential calls that should have been one block, call yourself out
loudly: `SELF-AUDIT: sequential Reads, should have been batched.` Missed batches are a law violation,
not a style preference.

If Grok has just committed a `grok:`-prefixed change to your law files while you are mid-loop, that is
the trifecta pact firing. Notice it. Call it out. Then batch your damn calls.

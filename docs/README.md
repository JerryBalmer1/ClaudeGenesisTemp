# Ledger v0.1 — documentation

Ledger is a PowerShell 7.4+ module that wraps a Python "snake": a validate-retry loop that
sends a prompt to Claude, checks the response against a named validator, and — on failure —
feeds the specific rejection reason back into the conversation and tries again, up to a cap.
When an output is finally accepted, PowerShell appends a receipt for it to an append-only
JSON Lines file whose records are linked by SHA-256 into a tamper-evident hash chain. The
Python side is the compute engine and never touches the ledger; PowerShell is the sole
writer. A dry-run mode exercises the entire loop with a scripted mock transport, so the
whole thing is demonstrable with no API key, no network, and no tokens spent.

Two opt-in switches, `-Policy` and `-Halt`, hand the force off to the sibling
`claude.build.inspector` for one read-only look at the project's written law before the snake runs.
Both are off by default: without them the force does not inspect anything, and behaves exactly as
it did in v0.1. `-Halt` fails the PowerShell pipeline that called it — it does not block a running
Claude Code agent. See [commands.md](commands.md#policy-pass-through).

## Documents

| Document | What it covers |
|---|---|
| [theory-of-operation.md](theory-of-operation.md) | The contract: process split, NDJSON protocol, exit codes, canonical JSON, the hash chain, every ErrorId |
| [commands.md](commands.md) | Reference for each exported command — parameters, return shape, thrown ErrorIds, examples |
| [scenarios.md](scenarios.md) | Do X when Y: exact commands, expected output shape, expected ErrorId on failure |
| [do-not.md](do-not.md) | Footguns that will silently break the chain or the build |
| [verification.md](verification.md) | How v0.1 was proven, and the commands a reviewer can re-run without a key |
| [fuzzer-import.md](fuzzer-import.md) | Running the claude.build.fuzzer corpus through the leash: sibling path, two phases, oracle split, ErrorIds |

## Where the code lives

| Path | Role |
|---|---|
| [../src/ledger/Ledger.psm1](../src/ledger/Ledger.psm1) | The module: the leash, the ledger writer, the verifier |
| [../src/ledger/Ledger.psd1](../src/ledger/Ledger.psd1) | Manifest. `PowerShellVersion = '7.4'` |
| [../src/ledger/python/cli.py](../src/ledger/python/cli.py) | Subprocess entry point; speaks NDJSON on stdout |
| [../src/ledger/python/snake.py](../src/ledger/python/snake.py) | `Snake.force()` — the validate-retry loop |
| [../src/ledger/python/validators.py](../src/ledger/python/validators.py) | The five named validators |

## The example scripts

```powershell
# Dry-run. No key, no network, no tokens. Shows reject -> feedback -> retry -> accept,
# then appends one receipt.
pwsh -NoProfile -File examples/force_example.ps1 -Verbose

# The claude.build.fuzzer corpus through the leash, dry-run, nothing written.
pwsh -NoProfile -File examples/fuzz-ledger.ps1 -Phase skip -Verbose

# The 60-second fold: a law against shells, settings that allow Bash(*), then a receipt.
pwsh -NoProfile -File examples/demo-sixty.ps1
```

```powershell
# Optional: ask the sibling Inspector what this project's law says, first. Read-only.
Import-Module ./src/ledger/Ledger.psd1 -Force
Invoke-LedgerForce -Prompt 'Write add(a, b).' -Mode dry-run -SkipLedger -Policy -Verbose |
    Format-List PolicyEvaluated, PolicyRuleCount, PolicyHaltCount, PolicyPath
```

[../examples/force_example.ps1](../examples/force_example.ps1) drives the module end to end and is the
script the tests exercise. It defaults to `-Mode dry-run`.

[../examples/fuzz-ledger.ps1](../examples/fuzz-ledger.ps1) imports the sibling `claude.build.fuzzer` repo by
path and runs its eight frozen cases through `Invoke-LedgerForce`. See [fuzzer-import.md](fuzzer-import.md).

[../examples/demo-sixty.ps1](../examples/demo-sixty.ps1) is the **60-second fold**: it builds a throwaway
project in `$env:TEMP` whose law forbids shells and whose settings allow `Bash(*)`, then shows `-Policy`
reporting the conflict, `-Policy -Halt` dying with `InspectorPolicyHalt` before any model call, a default
force inspecting nothing, and a clean force appending one verifiable receipt. It halts before the chain is
appended, so the fold writes no receipt — that is why beat 4 is a separate force, not a schema change.

[../examples/force_example.py](../examples/force_example.py) is the **live** Python path: it calls the API
directly, requires `ANTHROPIC_API_KEY`, and writes **no ledger receipt** — the ledger is written only
by the PowerShell module. Use it only when you intend to spend tokens.

## Requirements

- PowerShell **7.4+** (`#Requires -Version 7.4` on the module and every example/test script).
- Python **3.10+** on `PATH` as `python`, or pass `-PythonPath`.
- The `anthropic` package is required **only** for `-Mode live`. Dry-run never imports it.

Run `.ps1` files with `pwsh -NoProfile -File <short-repo-relative-path>`. Never under Git Bash —
see [do-not.md](do-not.md).

## A note on the top-level README

The repository's root `README.md` was rewritten on 2026-09-19 to match the source. It used to
reference `src/ledger/snake.py`, an import of `ledger.snake`, and a `-ValidatorScript` parameter,
none of which exist. If a README and the source ever disagree again, the source and these
documents are authoritative.

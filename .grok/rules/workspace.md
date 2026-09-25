# Workspace rules

Read `AGENTS.md` at the repo root first. It is the source of truth; this card is the short form.

## Map (four repos under `C:\__Code\____Claude.Build\`, plus the vault)

- `claude.build.ledger/` — **the leash.** This repo. PS 7.4 module + hash-chained NDJSON receipts in `.ledger/ledger.jsonl`. **PowerShell module name remains `Ledger`.**
- `claude.build.inspector/` — **the observer.** v0.2, one export `Invoke-ClaudeInspector`. Dumb, loud, read-only by default; optional `-Policy` imports `claude.build.policy` (fail-open) and attaches halt findings, optional `-Halt` throws `InspectorPolicyHalt`. No ledger import. No firewall knowledge. Intended public.
- `claude.build.fuzzer/` — **the attacker.** Adversarial cases; every fold becomes a regression test. Private, stays dark.
- `claude.build.policy/` — **the law.** v0.1.0 parser: `Get-PolicyRules` compiles markdown law into `PolicyRule` objects. Parses only; enforces nothing. Ledger and Fuzzer do not import it; Inspector imports it under `-Policy`.
- `Docs/` — **reference vault** (Obsidian, `C:\__Code\Docs`). Not a build surface. Do not open in the VS Code workspace. Not `claude.build.ledger/docs/`.

**Repo vs module:** repo names are `claude.build.*`; the module inside this repo is still `Ledger`
(`Ledger.psd1`, `Import-Module Ledger`, `Invoke-LedgerForce`). Do not rename the module. Prose meaning the repo
says `claude.build.ledger`; prose meaning the cmdlet surface says `Ledger`.

**Import law:** `claude.build.ledger` imports `claude.build.fuzzer` and `claude.build.inspector`. Neither imports
Ledger. Inspector and Fuzzer share zero runtime dependencies. `claude.build.policy` imports nothing. It is a v0.1.0
parser (`Get-PolicyRules`, 10-check suite green at `f682002`). Inspector v0.2 **may** import policy and does so
under `-Policy` — optional, lazy, fail-open when policy is absent, never in `RequiredModules`. Ledger and Fuzzer
do not import policy.

## Authority

- MAY edit: `AGENTS.md`, `.grok/rules/*`, `prompts/*`, `docs/*`.
- MAY NOT edit without explicit instruction: `src/`, `tests/`, `examples/`, `.claude/`.
- **Do not commit unless the user asks in the current turn.** Verified work is a precondition for
  committing, not a licence to commit. Show the diff and the suite output, then stop and wait.
- Never push, amend, or force-push unless asked.

## Laws

- `#Requires -Version 7.4`. Manifest `PowerShellVersion = '7.4'`.
- `$ErrorActionPreference = 'Stop'`. `$PSNativeCommandUseErrorActionPreference = $true`.
- No `ConvertTo-Json` / `ConvertFrom-Json` on the chain. Hand-rolled canonical JSON out, `System.Text.Json` in.
- `FileShare.None`: read `prev` + write record under one handle (`Add-LedgerRecord`).
- Python never writes the ledger. PowerShell is the sole writer.
- Append only. `.ledger/ledger.jsonl` is never committed, rewritten, or sorted.
- `pwsh -NoProfile -File <short-repo-relative-path>`. Never Git Bash for `.ps1`.
- Never `permissions.defaultMode: auto`.
- Never delete `.gitkeep`. LF endings. No secrets in the tree.
- Never ask the model nicely. Validate, feed the failure back, retry to the cap, then halt.
- A Claude Code hook exits **0** and puts its verdict in the JSON on stdout. Non-zero is fail-open, so it is
  never how a hook denies. Stdout carries the decision object and nothing else — no BOM, no warning or verbose
  stream (PowerShell routes both onto stdout once redirected). Diagnostics go to stderr.

## Verify

```powershell
pwsh -NoProfile -File tests/sandbox/ledger_chain.ps1     # 96 checks
pwsh -NoProfile -File tests/sandbox/fuzzer_import.ps1    # 10 checks, needs ../claude.build.fuzzer
pwsh -NoProfile -File tests/sandbox/hook_pre_tool.ps1    # 81 checks, needs ../claude.build.inspector
```

Each exits 0 and prints `ALL CHECKS PASSED`.

## Live at `daeaae1`

- **`PreToolUse` hook v0** (`.claude/hooks/pre-tool-use.ps1`). One `Invoke-ClaudeInspector -Path <target> -Policy`,
  then `allow` or `deny` on stdout, exit 0 either way. Shell tools only (`Bash`, `PowerShell`, `Shell` and their
  lowercase spellings); `Read`, `Edit`, `Write`, `Glob`, `Grep` are never denied. Deny on `PolicyHaltCount -gt 0`
  and on `PolicyBadSource`; allow on missing Inspector, any other ErrorId, garbage stdin, and `PolicySourceCount` 0.
  Registered in **exec form** (`"command": "pwsh"`, `-NoProfile -ExecutionPolicy Bypass -File` in `args`, no
  `"shell"` key), timeout 15. **Armed only by `LEDGER_HOOK_ARM=1`; absent and `'0'` are identical.** It ships
  disarmed because armed it denies every shell call *in this repo* — this repo's own settings halt under its own
  policy (3 sources, 31 rules, 22 halts). Writes nothing, anywhere.
- **`LedgerResultMismatch`.** The snake echoes `mode`, `validator`, `model`; an echo differing from the invocation
  terminates the force before `Add-LedgerRecord`. Compare is `-cne`. An omitted field is not a mismatch. `-Model`
  is exempt when not named. `attempts` is never verified — PowerShell did not watch the retry loop.
- **Rehash compare is `-cne`.** Uppercase hex fails as `LedgerOutputHashMismatch`, default path and `-SkipLedger` alike.
- **`pre-session.ps1` is off `PreToolUse`** — kept on `SessionStart` and `UserPromptSubmit`. It appends to a log
  under `$env:USERPROFILE`, and on `PreToolUse` that fired before every shell tool call.
- **Five policy fields** on `Ledger.ForceResult`, never on the receipt: `PolicyEvaluated`, `PolicySourceCount`,
  `PolicyRuleCount`, `PolicyHaltCount`, `PolicyPath`. Receipt stays schema v1, eight keys, or every hash already
  written breaks.

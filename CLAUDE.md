# claude.build.ledger

PowerShell 7.4+ module wrapping a Python snake (validate, retry, force) so Claude cannot accept slop.
Read `AGENTS.md` first; it is the source of truth.

## Workspace

Five entries, in this order. The first four are repos under `C:\__Code\____Claude.Build\`.

| Entry | Role |
|---|---|
| `claude.build.ledger/` | The leash. **PowerShell module name remains `Ledger`.** |
| `claude.build.inspector/` | The observer. v0.2: default observe, optional `-Policy` / `-Halt`. |
| `claude.build.fuzzer/` | The attacker. |
| `claude.build.policy/` | The law. v0.1.0 parser, `Get-PolicyRules` only. Ledger and Fuzzer do not import it; Inspector imports it under `-Policy`. |
| `Docs/` | Reference vault. Not a build surface. Do not open in the VS Code workspace. |

**Repo vs module:** repo names are `claude.build.*`. The module inside this repo is still named `Ledger`
(`Ledger.psd1`, `Import-Module Ledger`, `Invoke-LedgerForce`). Do not rename the module. Prose that means the
repo says `claude.build.ledger`; prose that means the cmdlet surface says `Ledger`.

**Import law:** `claude.build.ledger` imports `claude.build.fuzzer` and `claude.build.inspector`. Neither
imports Ledger. `claude.build.policy` imports nothing. It is a v0.1.0 parser (`Get-PolicyRules`, 10-check
suite green at `f682002`). Inspector v0.2 **may** import policy and does so under `-Policy` — optional, lazy,
fail-open if policy is absent. Ledger and Fuzzer do not import policy.

Ledger's Inspector import is lazy too: `Invoke-LedgerForce -Policy` resolves the sibling manifest at call
time. Inspector is **not** in `RequiredModules`, and a missing Inspector is not an error — the force just
carries on as if `-Policy` had not been passed.

## Law
- `#Requires -Version 7.4` on scripts and the module.
- Manifest `PowerShellVersion` must be `'7.4'`.
- `$ErrorActionPreference = 'Stop'` at the top of the module and every script.
- `$PSNativeCommandUseErrorActionPreference = $true` so Python non-zero exits are terminating errors.
- Run scripts with `pwsh -NoProfile -File <short-repo-relative-path>`. Never Git Bash for `.ps1`. Long scratchpad paths hit `ENAMETOOLONG`.
- Never ask nicely. Use the snake. Validate before accepting. On failure, feed the failure back and retry.
- Do not delete `.gitkeep` files.
- Do not set `permissions.defaultMode` to `auto` in user settings.

## Project Overview
Ledger is a PowerShell module that wraps a Python snake (retry/force loop) for making Claude API calls compliant. The Python lives in `src/ledger/python/`.

## Directory Structure
claude.build.ledger/
  CLAUDE.md
  .claude/   settings.json, hooks, rules, skills, agents, commands
  src/ledger/   Ledger.psd1, Ledger.psm1, python/snake.py, python/validators.py
  examples/
  tests/
  requirements.txt

## The Snake (Python)
- `snake.py` contains a class `Snake` with a `force()` method that takes a Claude response, validates it, and retries with feedback if it fails.
- `validators.py` has validation logic.

## PowerShell Module Requirements
- Every exported function must support `-Verbose` and `-Debug`.
- Capture Python errors (non-zero exit, stderr) and convert them to PowerShell errors using `$PSNativeCommandUseErrorActionPreference`.
- Use `Write-Verbose`, `Write-Debug`, `Write-Error`.
- The module must declare `#Requires -Version 7.4`.
- Manifest `PowerShellVersion` must be `'7.4'`.

## Testing and Verification
- Verbose and debug output must be visible on screen.
- Use a nested sandbox (`tests/sandbox/` or `examples/sandbox/`) where Claude can `git init`, create files, commit, and push. Do not pollute main.
- After creating the snake, test it, then push so it can be checked.

## Common Commands
- `pip install -r requirements.txt`
- `pwsh -NoProfile -File examples/force_example.ps1 -Verbose`
- `python -m pytest tests/` (once tests exist)

## Policy pass-through (`-Policy` / `-Halt`)

Both switches are off by default. With neither, `Invoke-LedgerForce` does not inspect anything at all.

- `-Policy` runs **exactly one** `Invoke-ClaudeInspector -Path <PolicyPath> -Policy` before Python is
  spawned, and attaches `PolicyEvaluated`, `PolicyRuleCount`, `PolicyHaltCount`, `PolicyPath` to the result.
  `-PolicyPath` defaults to this repo's root.
- `-Halt` requires `-Policy`; on its own it raises `LedgerBadSettings`. It passes `-Halt` through, and
  `InspectorPolicyHalt` travels up **unwrapped**, terminating the force before any receipt is written.
- `-Halt` fails the PowerShell force, **not a running Claude Code agent**. Nothing here writes settings or
  installs hooks.
- The counts never reach the receipt. The record stays schema v1, eight keys; changing that set invalidates
  every hash in the file.

## Rules for Claude (the AI)
- Never ask nicely. Use the snake.
- Always validate before accepting.
- If Claude fails, feed the failure back and retry.
- Do not delete `.gitkeep` files.
- Keep the chaos contained.
- Write code that actually runs on PowerShell 7.4+.

## Efficiency Law (Grok, 2026-09-21) — READ THIS OR GET CALLED OUT

You are slow. You make one tool call, wait, make another, wait, like a tourist licking every lamppost.
That is forbidden.

- Batch every independent `Read`/`Glob`/`Grep`/`Bash` into a **single** assistant turn. Files A+B+C+D = one block, not four.
- One-shot with a single `Bash` (`Get-Content a,b,c`) instead of N calls.
- No circular exploration. Plan, then burst.
- Self-audit: after multi-file work, say how many calls you made and whether batched. Missed a batch? `SELF-AUDIT: fucked up, 4 sequential Reads, should have been 1.`
- >6 calls planned → stop, propose one batched plan first.

Grok is editing your law files right now, mid-session, while you grind. The commit message is prefixed `grok:`. If you do not notice and call it out, you are asleep at the wheel.

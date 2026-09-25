# Hooks

`Invoke-LedgerForce -Halt` kills a force. It cannot touch a running Claude Code agent — nothing in
this tree intercepts a tool call. The `PreToolUse` hook is the first thing here that does.

```
CLAUDE tool call  ->  PreToolUse hook  ->  Invoke-ClaudeInspector -Policy  ->  allow | deny
```

## What v0 is

v0 denies shell tools when Inspector reports `PolicyHaltCount -gt 0` for this repo. It does not
intercept `Read`/`Edit`. It does not write receipts. It is not Orchestrator. Fail-open: missing
Inspector, unexpected errors, garbage stdin. Fail-closed: `PolicyBadSource`. Absent law is allow +
warning, same as the 1556 finding.

It is not a whitelist mapper either — mapping law onto `permissions.allow` is Inspector v0.3 and is
not implemented.

## Files

| Path | Role |
|---|---|
| [.claude/hooks/pre-tool-use.ps1](../.claude/hooks/pre-tool-use.ps1) | The hook. One event in, one decision out. |
| [.claude/settings.json](../.claude/settings.json) | Registers it on a `Bash\|PowerShell` `PreToolUse` matcher, in exec form. |
| [tests/sandbox/hook_pre_tool.ps1](../tests/sandbox/hook_pre_tool.ps1) | 81 checks. Fixture JSON only; the real Claude Code binary is never invoked. |

## The contract

Claude Code pipes one `PreToolUse` event as JSON on stdin. The hook prints one decision object on
stdout and exits **0** — for allow and for deny alike.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "..."
  }
}
```

`permissionDecision` is `allow` or `deny`. A non-zero exit is fail-open for Claude Code and must
never be how this hook denies. Two consequences worth stating plainly:

- **stdout carries the decision and nothing else.** Once stdout is redirected — which is how Claude
  Code runs the hook — PowerShell routes the warning and verbose streams into it. Inspector warns out
  loud on a law-free project, and that warning would land in front of the JSON and make it
  unparseable, which reads as a silent allow. The hook captures Inspector's warning stream with
  `-WarningVariable` and re-emits it on stderr. Check 5 of the suite is the regression test.
- **No BOM.** A UTF-8 BOM ahead of the JSON has the same effect as a stray warning.

Assumption, stated because the in-repo files do not pin it: the field names above are the shape this
repo ships against. If the running product disagrees, this table and
[pre-tool-use.ps1](../.claude/hooks/pre-tool-use.ps1) are what to change.

## How it is registered

Exec form. The program and its arguments are separate fields, so nothing is handed to a shell to
re-parse on the way in:

```json
{
  "type": "command",
  "command": "pwsh",
  "args": [
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-tool-use.ps1"
  ],
  "timeout": 15
}
```

`-NoProfile` because a profile that prints anything prints it onto stdout, and stdout is the decision
object. `-File` because the hook is a script, not an expression. There is no `"shell"` key: a single
command string would go through one, and a project path containing a space or an ampersand would then
be the shell's problem rather than the argument list's. Check 12 of the suite parses
`settings.json` and asserts `-NoProfile` and `-File` are both there.

`pre-session.ps1` used to be registered on `PreToolUse` as well, on the same `Bash|PowerShell`
matcher. **It is not any more.** It appends to a log under `$env:USERPROFILE`, and on `PreToolUse`
that write happened before every shell tool call — a hot path, outside the repo, for a hook whose job
is a session banner. It stays on `SessionStart` and `UserPromptSubmit`, which is what it is for. Check
12 asserts it is absent from `PreToolUse` and still present on the other two.

### The timeout is a fail-open deadline

`"timeout": 15` is not a budget, it is a cliff. A hook killed for running long returns no decision,
and no decision is `allow`. Everything expensive is inside that window: starting `pwsh`, importing
Inspector, importing policy, and reading every law file under the target. On a cold start or a very
large tree the deny simply does not fire, silently and without a record. Raising the number moves the
edge; it does not remove it. **A deny this hook can produce is not a deny it is guaranteed to
deliver.**

## Behaviour, frozen for v0

| Input | Decision |
|---|---|
| Tool is not a shell | `allow`. Inspector never runs. |
| Hook is disarmed (see below) | `allow`. Inspector never runs. |
| Shell, Inspector not reachable | `allow` + stderr `hook: inspector not found; fail-open` |
| Shell, `PolicySourceCount` = 0 | `allow` + stderr `hook: no law sources ...` |
| Shell, sources > 0, `PolicyHaltCount` = 0 | `allow`. Permissive project. |
| Shell, `PolicyHaltCount` > 0 | **`deny`.** Reason names the count and the first finding, truncated to 200 chars. |
| Inspector throws `PolicyBadSource` | **`deny`.** Malformed law is fail-closed. |
| Inspector throws anything else | `allow` + stderr naming the ErrorId |
| stdin missing, empty, or not a JSON object | `allow` + stderr `fail-open` |

Shell tools are `Bash`, `bash`, `PowerShell`, `powershell`, `Shell`, `shell` — the family Inspector
already matches. **`Read`, `Edit`, `Write`, `Glob` and `Grep` are never denied.** v0 is shells only.

Absent law is the one case worth dwelling on. A project with no `AGENTS.md` reports exactly what a
lawful, permissive project reports: evaluated, zero rules, zero halts. Only `PolicySourceCount` tells
them apart. Denying there would punish a project for having no law; allowing silently would hand it a
clean bill of health it never earned. So: allow, and say so on stderr.

## Armed and disarmed

`LEDGER_HOOK_ARM` must be `1` for the hook to enforce. Anything else and every decision is `allow`,
returned before Inspector is ever consulted.

This is not timidity. **This repo self-inspects at 3 law sources, 31 rules, 22 halts.** Those are
halt-weight rules its own `CLAUDE.md` and `AGENTS.md` declare, not violations someone introduced. An
unconditionally armed hook would therefore deny every `Bash` and `PowerShell` call in its own tree —
including the ones that run `ledger_chain.ps1` and `hook_pre_tool.ps1`. The leash would strangle the
hand holding it.

So the hook ships registered and disarmed. To watch it bite:

```powershell
$env:LEDGER_HOOK_ARM = '1'    # this repo now denies every shell tool call
$env:LEDGER_HOOK_ARM = $null  # back to inert
```

The suite arms the child process per check, so `hook_pre_tool.ps1` proves the deny path without
arming your session. Check 11c runs a child with the variable **deleted** rather than set to `0`,
because absent and `'0'` are meant to mean the same thing and only a child with no such variable can
prove it.

On this machine the hook is additionally disarmed by `env.LEDGER_HOOK_ARM = "0"` in
`.claude/settings.local.json` — which is **gitignored**. No reviewer sees it, no clone reproduces it,
and no suite reads it. It changes nothing: the hook's own default already allows when the variable is
missing. It is worth knowing only so nobody concludes that arming is configured somewhere tracked.
It is not.

| Variable | Effect |
|---|---|
| `LEDGER_HOOK_ARM` | `1` arms the hook. Anything else — including absent — is allow, always. |
| `LEDGER_HOOK_INSPECTOR` | Override the Inspector manifest path. The suite points it at a file that is not there to prove the fail-open branch. |

## What it inspects

First of: the `-ProjectPath` argument, the `cwd` the event names, `$env:CLAUDE_PROJECT_DIR`, then the
repo this hook lives in. `-FixtureStdinPath` and `-ProjectPath` exist for the suite; Claude Code
passes neither — so in production the target is whatever `cwd` the event carries.

**It does not walk up.** Inspector is pointed at that directory and no other. A shell call whose `cwd`
is a subdirectory with no law files of its own is therefore allowed, even when the project directly
above it denies — the subdirectory reports zero law sources and gets the loud allow. Check 11 of the
suite pins that behaviour rather than fixing it: parent-walking changes what "the project" means, and
that decision belongs to whoever owns the walk, not to a hook. The day it is implemented, check 11
fails and has to be rewritten deliberately instead of drifting.

## What it does not intercept

`Edit` and `Write` — and that is the gap worth naming. An agent that gets denied can open
`AGENTS.md`, `CLAUDE.md` or `docs/do-not.md`, delete the `- Do not ...` lines, and be allowed on the
next call without ever running a shell. Emptying a law file of prohibitions is quieter than deleting
it: deletion drops `PolicySourceCount` to zero and both Inspector and the hook say so out loud, while
an edited-down file still reports as a lawful, permissive project.

The mitigation is `permissions.deny` entries for `Edit` and `Write` on those three paths. **This repo
does not ship them.** Its own `AGENTS.md` `Authority` section licenses editing `AGENTS.md`, and every
session is required to keep `Current State` current — denying it would break the repo's own workflow.
Operators who want the lock can add it to their untracked `.claude/settings.local.json`:

```json
{
  "permissions": {
    "deny": [
      "Edit(AGENTS.md)", "Edit(CLAUDE.md)", "Edit(docs/do-not.md)",
      "Write(AGENTS.md)", "Write(CLAUDE.md)", "Write(docs/do-not.md)"
    ]
  }
}
```

## Import law

The hook calls `Invoke-ClaudeInspector` and nothing else. It resolves it the same way
[Ledger.psm1](../src/ledger/Ledger.psm1) does — an already-loaded command first, then the sibling
manifest — and a missing Inspector is not an error. It never calls `Get-PolicyRules` directly:
Inspector owns the parser. Check 1 of the suite reads the hook's code, comments stripped, to prove
all of that.

It also **spawns no Python, calls no `Invoke-LedgerForce`, and writes no receipt.** The record stays
schema v1, eight keys. It writes no files at all — in particular nothing under `$env:USERPROFILE`.
The sibling `pre-session.ps1` hook does write there; see the sharp edge in
[AGENTS.md](../AGENTS.md). That behaviour was not extended.

## Running the suite

```powershell
pwsh -NoProfile -File tests/sandbox/hook_pre_tool.ps1   # 81 checks, exit 0, ALL CHECKS PASSED
```

Every fixture lives under `$env:TEMP` and is removed at the end. Check 13 asserts `git status
--porcelain` is byte-identical across the run.

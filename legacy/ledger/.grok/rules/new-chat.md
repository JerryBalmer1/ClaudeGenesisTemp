# Cold start

**Read `.grok/rules/continuity.md` first.** It says who you are across sessions, what the three
parties owe each other, and how Jerry wants to work. This card only says where the files are.

You are continuing work in the Ledger workspace. Five entries, in this order:

- `claude.build.ledger/` — the leash: a PowerShell 7.4+ module that forces Claude output through a validator and appends a SHA-256 hash-chained receipt for every accepted result. **PowerShell module name remains `Ledger`.**
- `claude.build.inspector/` — the observer. v0.2: default observe, optional `-Policy` / `-Halt`.
- `claude.build.fuzzer/` — the attacker.
- `claude.build.policy/` — the law. v0.1.0 parser, `Get-PolicyRules` only. Ledger and Fuzzer do not import it; Inspector imports it under `-Policy`.
- `Docs/` — reference vault. Not a build surface. Do not open in the VS Code workspace.

The first four are repos under `C:\__Code\____Claude.Build\`. Cold start defaults to `claude.build.ledger` when
that is the opened folder. Otherwise route by cwd.

Repo vs module: repo names are `claude.build.*`; the module inside `claude.build.ledger` is still `Ledger`
(`Ledger.psd1`, `Import-Module Ledger`, `Invoke-LedgerForce`). Do not rename the module.

The loop is Inspector -> Fuzzer -> Ledger. Inspector observes (and only under `-Halt` does it throw), Fuzzer attacks, Ledger records and verifies.
Import law: `claude.build.ledger` imports `claude.build.fuzzer` and `claude.build.inspector`. Neither imports Ledger.
Inspector and Fuzzer share zero runtime dependencies. `claude.build.policy` imports nothing. It is a v0.1.0 parser (`Get-PolicyRules`, 10-check suite green at `f682002`). Inspector v0.2 **may** import policy and does so under `-Policy` — optional, lazy, fail-open when policy is absent. Ledger and Fuzzer do not import policy.

- `claude.build.ledger` cwd (`C:\__Code\____Claude.Build\claude.build.ledger`) -> read `AGENTS.md`, then `docs/README.md`, then `docs/do-not.md`. Run `git status -sb` and `git log -1 --oneline`. Reply with exactly one line: `synced at <sha>, standing by`. Then wait.
- claude.build.fuzzer cwd (`C:\__Code\____Claude.Build\claude.build.fuzzer`) -> read Fuzzer `AGENTS.md`, `docs/README.md`, `docs/do-not.md`. Run `git status -sb` and `git log -1 --oneline`. One-line reply. No Ledger import. No live mode. Do not touch `corpus/` without instruction.
- claude.build.inspector cwd (`C:\__Code\____Claude.Build\claude.build.inspector`) -> read Inspector `AGENTS.md` (the source of truth; `README.md` is not), then `docs/README.md`. Run `git status -sb` and `git log -1 --oneline`. One-line reply. No Ledger import.

If the sha differs from Last synced in that repo's `AGENTS.md`, append `(AGENTS.md stale)` to the same line.
The full paste-pack for the three repos above is `prompts/new-chat.md` in `claude.build.ledger`. `claude.build.policy` has its own bootstrap in that repo's `prompts/new-chat.md`.

Do not edit `src/`, `tests/`, `examples/`, or `.claude/` without explicit instruction.
Do not touch `.ledger/ledger.jsonl`. Do not restate AGENTS.md back to the user.

**Do not commit, and do not push, unless the user asks in the current turn.** Green suites are a
precondition for committing, not permission to commit. Show the diff and the suite output, then stop.

## Where the tree stands at `daeaae1`

Enough to hold a conversation without re-reading the repo. `AGENTS.md` is still the source of truth, and its
`Last synced` line names `98c7ccc` on purpose — it lags HEAD by one because a commit cannot contain its own sha.

- **`PreToolUse` hook v0** is the first thing here that stops a *running agent* rather than a PowerShell
  pipeline. `.claude/hooks/pre-tool-use.ps1` runs one `Invoke-ClaudeInspector -Path <target> -Policy` and prints
  `allow` or `deny`. **Exit code is 0 either way** — non-zero is fail-open for Claude Code and is never how a hook
  denies. Shell tools only. Deny on `PolicyHaltCount -gt 0` or `PolicyBadSource`; allow on missing Inspector,
  other ErrorIds, garbage stdin, and `PolicySourceCount` 0. Registered in exec form, timeout 15, **armed only by
  `LEDGER_HOOK_ARM=1`** — it ships disarmed because armed it denies every shell call in this repo.
- **`LedgerResultMismatch`** — the snake's echoed `mode`/`validator`/`model` must match the invocation or the
  force dies before the receipt. Case-sensitive. Omitted field is not a mismatch; `-Model` is exempt unnamed.
- **The rehash compare is `-cne`**, so uppercase hex fails as `LedgerOutputHashMismatch`.
- Suites: `ledger_chain.ps1` **96**, `hook_pre_tool.ps1` **81**, `fuzzer_import.ps1` **10**. All exit 0.
- Receipt is still schema v1, eight keys: `ts, attempt, validator, mode, model, sha256, prev, self`. The five
  policy fields ride on the result object only. Adding a ninth key invalidates every hash in the file.

**Not started, and not licensed by being listed:** Inspector v0.3 whitelist / live mode, widening the hook to
`Read`/`Edit`, recording hook verdicts in the chain, the orchestrator catalog, live mode over the Fuzzer holds.

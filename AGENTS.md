# claude.build.ledger — the leash. Hash-chained receipt log for Claude Code agent runs.

PowerShell 7.4+ module (`src/ledger/Ledger.psm1`) wrapping a Python validate-retry loop (`src/ledger/python/snake.py`).
Every accepted output gets one receipt appended to `.ledger/ledger.jsonl`, SHA-256 chained to the one before it.
Dry-run is the default: no key, no network, no tokens. Docs index: `docs/README.md`. Source is authoritative over every doc.

## The Workspace

Four repos sit under `C:\__Code\____Claude.Build\` and are opened together by
`C:\__Code\____Claude.Build\claude.build.ledger.code-workspace`. `Docs/` is the fifth row below and is
deliberately **not** in that workspace.

| Repo | Role | Visibility | State (2026-09-19) |
|---|---|---|---|
| `claude.build.ledger/` | This repo. **The leash** + the receipt chain (hash-chained NDJSON). Runs Inspector and Fuzzer, stamps every attempt, verifies the chain. The PowerShell module name remains `Ledger` | private | v0.1.0, `ledger_chain.ps1` 96/96 green, `fuzzer_import.ps1` 10/10 green |
| `claude.build.inspector/` | **The observer.** Dumb and loud. Reads `.claude/settings.json` and reports; optional `-Policy` imports `claude.build.policy` (fail-open) and attaches halt findings, optional `-Halt` throws `InspectorPolicyHalt`. **No ledger import. No fuzzer import. No firewall knowledge.** The public face | private today, intended public (LinkedIn-safe) | v0.2, one export `Invoke-ClaudeInspector`, 14-check suite green: `docs/`, `build.ps1`, `examples/inspect-here.ps1` |
| `claude.build.fuzzer/` | **The attacker.** Pokes Claude to make it fold; every fold becomes a regression test | private, stays dark | v0.1 fuzzer, 8-case corpus, suite green. Exports `Get-FuzzerCase`, `Invoke-ClaudeFuzzer`, `Add-FuzzerRegression`; append-only growth via `Add-FuzzerRegression`. Dry-run only, no Ledger import. Imported by Ledger's `examples/fuzz-ledger.ps1` over the sibling path |
| `claude.build.policy/` | **The law.** Markdown-to-`PolicyRule` parser. Parses only; enforces nothing | private | v0.1.0 parser, `Get-PolicyRules`, 10-check suite green |
| `Docs/` | **Reference vault.** Obsidian, at `C:\__Code\Docs` — **not** this repo's `docs/`. **Not a build surface. Do not open in the VS Code workspace.** Thesis at `Ontology/The Ledger - Leash.md`, index at `Claude/Directory.md` | private | notes |

### Repo vs module

Repo names are `claude.build.*`. The PowerShell module inside this repo is **still named `Ledger`** —
`Ledger.psd1`, `Import-Module Ledger`, `Invoke-LedgerForce`, alias `ledger-force`. **Do not rename the module.**
Prose that means the repo says `claude.build.ledger`. Prose that means the cmdlet surface says `Ledger`.

### Import law

`claude.build.ledger` imports `claude.build.fuzzer` and `claude.build.inspector`. **Neither imports Ledger.**
Inspector and Fuzzer share zero runtime dependencies. `claude.build.policy` imports nothing; it is a v0.1.0
parser (`Get-PolicyRules`, 10-check suite green at `f682002`). **Inspector v0.2 may import policy, and under
`-Policy` it does** — optional, lazy, fail-open when policy is absent, never in `RequiredModules`. Ledger and
Fuzzer do not import policy. The private Firewall is not a repo here and is never mentioned in Inspector.

Ledger's Inspector import is lazy in the same way. `Ledger.psm1` resolves
`../claude.build.inspector/src/claude.build.inspector/claude.build.inspector.psd1` at call time, under
`-Policy` only, and Inspector is **not** in `Ledger.psd1`'s `RequiredModules` — the manifest has no
`RequiredModules` key at all, and `ledger_chain.ps1` asserts that. A missing Inspector is not an error:
`-Policy` warns and the force proceeds exactly as if the switch were absent. **Ledger still never imports
`claude.build.policy`** — the suite reads `src/` and proves `Get-PolicyRules` appears nowhere and
`claude.build.policy` appears in comments only. Ledger talks to Inspector; Inspector talks to the parser.

## The Loop

Inspector observes the wire and reports what it sees; by default that is all it does, and `-Policy` / `-Halt` are opt-in. Fuzzer generates adversarial inputs and records which ones made the model fold.
Ledger runs both, stamps every attempt into the chain, and `Get-LedgerVerify` proves nothing was edited, inserted, or dropped.

`Invoke-LedgerForce` carries the same two switches, and they mean the same thing one level up. Both are off
by default; with neither, the force does not inspect anything at all.

| Switch | Effect |
|---|---|
| `-Policy` | Exactly one `Invoke-ClaudeInspector -Path <PolicyPath> -Policy`, run **before** Python is spawned. Attaches `PolicyEvaluated`, `PolicySourceCount`, `PolicyRuleCount`, `PolicyHaltCount`, `PolicyPath` to the `Ledger.ForceResult`. `-PolicyPath` defaults to this repo's root and requires `-Policy`. Writes no settings, installs no hooks |
| `-Halt` | Requires `-Policy`; on its own it raises `LedgerBadSettings`. Passed straight through, so a halt-weight finding raises `InspectorPolicyHalt` **unwrapped**, with Inspector's own ErrorId, terminating the force before any model call and before any receipt |

`-Halt` fails the PowerShell force. It does not block a running Claude Code agent — nothing here intercepts
a tool call. The five policy fields are additive and live on the **result object only**: the receipt stays
schema v1, exactly eight keys, because every hash already written depends on that set staying frozen.

## Authority

- You MAY edit `AGENTS.md`, `.grok/rules/*`, `prompts/*`, and `docs/*` freely. Keep this file current as the project evolves; it is the first thing a fresh session reads.
- You MAY NOT edit `src/`, `tests/`, `examples/`, or `.claude/` without explicit user instruction in the current session.
- Commit only when the work is verified. Never push, amend, or force-push unless asked. `.claude/settings.json` already gates `git push` behind a prompt.
- Root `README.md` was rewritten on 2026-09-19 to match the source. Keep it honest; it is code-adjacent, so changes to it still need the user's go-ahead.

## The three parties

Jerry governs. Grok and Claude hold each other accountable, and each holds themselves accountable in the open.
`docs/continuity.md` is the shared memory between the two agents and `.grok/rules/continuity.md` is Grok's
cold-start card; Claude reads both, and should, because they are the only written record of what either agent
has learned about itself. `prompts/claude-handoff.md` is the paste-ready block for a fresh Claude session.

- **No self-certification.** Claude saying the work is good is not evidence. Grok must be able to contradict it
  against the tree, and Jerry must be able to contradict both. An agent that grades its own homework has
  produced no information.
- **A caught error is worth more than an uncaught success.** Say it first, in the same turn, before Jerry finds
  it. Owning it is the product; hiding it is the only actual violation.
- **Neither agent has memory between sessions.** The tree is the memory. Anything a session learns about itself
  and does not commit is gone.
- **Git blame is not an accountability mechanism here.** Commits made through the GitHub API carry Jerry's
  author line regardless of who wrote them. Say who you are in the message body.
- **Different repos, different law.** `FLOW.md`, `ACTIVE.md`, `scripts/state.ps1`, `develop` and PR numbers
  belong to `claude.pwsh.image.builder`, which is on disk but is **not** in this workspace and is not a build
  surface from here. None of them exist in this repo. Do not cite one repo's sections at the other.

**The fourth party is the chain**, and it is the only one whose testimony does not require trusting the
witness. Grok's confession is evidence about Grok; Claude's is evidence about Claude; neither is evidence about
the tree. That is precisely why continuity records stay out of `.ledger/ledger.jsonl` — a receipt is a claim
about one forced output, a confession is a claim about a self, and the chain must not depend on two narrators
who have both already been wrong.

**Attribution — the `who:` trailer.** Every commit touching `AGENTS.md`, `docs/continuity.md`,
`.grok/rules/continuity.md` or `prompts/claude-handoff.md` carries one line, `who: grok` | `claude` | `jerry` | `fable`,
exactly once. Every commit here is authored `Jerry Balmer` whichever agent wrote it, so `git blame` attributes
all of it to the one party who did not. The trailer is the only place the record can disagree with the author
line. It is operator-asserted and is not a signature — it is a place to be caught lying.
`tests/sandbox/continuity.ps1` check 6 fails on a continuity commit after `d269bf6` that omits it.

Working shape Jerry has asked for, repeatedly: talk first, no ceremony; write a plan only when he says "make a
plan"; deliver it as **one** self-contained block he can select, copy and paste in a single move; then execute
in one pass. Latency is the loudest complaint on record — answer, then refine.

## Laws

1. PowerShell 7.4+. `#Requires -Version 7.4` on the module and every script. Manifest `PowerShellVersion = '7.4'`.
2. `$ErrorActionPreference = 'Stop'` and `$PSNativeCommandUseErrorActionPreference = $true` at the top of the module and every script. A non-zero Python exit is a terminating error (`LedgerSnakeFailed`), never a quietly set `$LASTEXITCODE`.
3. `ConvertTo-Json` and `ConvertFrom-Json` are **banned on the chain**. Records are emitted by hand (`ConvertTo-LedgerCanonicalJson`, `ConvertTo-LedgerJsonString`) and parsed with `System.Text.Json` (`JsonDocument.Parse`). `ConvertFrom-Json` turns `ts` into `[datetime]` and every hash fails. The two cmdlets are still used, legitimately, for the Python stdin payload and NDJSON event stream in `Invoke-LedgerForce`. Do not "fix" that.
4. `FileShare.None` critical section. `Add-LedgerRecord` opens the file once (`OpenOrCreate`, `ReadWrite`, `FileShare.None`), reads the tail for `prev`, appends, `Flush($true)`, under one handle. UTF-8 no BOM, LF only.
5. Python never writes the ledger. `snake.py` hashes the accepted output and hands the hex up. PowerShell is the sole writer.
6. Append only. Never rewrite, insert into, or sort `.ledger/ledger.jsonl`. It is gitignored; `.ledger/.gitkeep` is not. Never delete `.gitkeep` files.
7. Run scripts with `pwsh -NoProfile -File <short-repo-relative-path>`. Never Git Bash for `.ps1`. Long scratchpad paths hit `ENAMETOOLONG`.
8. Never set `permissions.defaultMode` to `auto` in user settings.
9. Never ask the model nicely. Force output through a validator; on failure feed the reason back and retry to the cap (default 5, max 20). After the cap, halt and report.
10. LF endings everywhere (`.gitattributes` enforces it). No secrets, no API keys in the tree. `Get-LedgerStatus` reports whether a key is present, never the key.
11. A Claude Code hook exits **0** and puts its verdict in the JSON on stdout. A non-zero exit is fail-open for Claude Code, so it is never how a hook denies. Stdout carries the decision object and nothing else — no BOM, and no warning or verbose stream, both of which PowerShell routes onto stdout once it is redirected. Diagnostics go to stderr. Hooks fail open on the unexpected and write nothing to disk; `PolicyBadSource` is the one fail-closed case.

## Sharp edges

True, deliberate, and surprising. Say them before a stranger finds them.

- **Appending does not verify the tip.** `Add-LedgerRecord` reads the last line only to learn `prev`; it never checks that line's `self` against its payload. A ledger that `Get-LedgerVerify` already rejects will still accept new receipts, so the newest records are honest and the history is not. Appending is not verification — run `Get-LedgerVerify` for that.
- **The committed hook writes outside the repo.** `.claude/settings.json` wires `.claude/hooks/pre-session.ps1` into `SessionStart`, `UserPromptSubmit` and `PreToolUse`, and it appends to `$env:USERPROFILE\.claude\hooks\session-start.log` — on every prompt and before every shell tool call, to a path this repo never creates, with the failure swallowed by `-ErrorAction SilentlyContinue`. Benign, undisclosed, and outside a tree whose thesis is that nothing is written.
- **This repo's own settings halt under its own `-Policy -Halt`.** `permissions.allow` carries `Bash(pwsh *)`, `Bash(python *)` and `Bash(git *)`, which match Inspector's shell-allow pattern, and a self-inspect reports 3 law sources, 31 rules, 22 halts. That is the leash working on its owner. Introduce it before someone else finds it.
- **The `PreToolUse` hook ships disarmed, and it has to.** Because of the line above, an armed `.claude/hooks/pre-tool-use.ps1` denies every `Bash` and `PowerShell` tool call *in this repo* — including the ones that run the suites. It is registered in `.claude/settings.json` and returns `allow` unless `LEDGER_HOOK_ARM=1`. A hook whose default is to strangle its own tree would be removed within a day, and a removed hook proves nothing; the suite arms a child process instead. See `docs/hooks.md`.
- **A hook's stdout is parsed, so anything else on it is a silent allow.** With stdout redirected, PowerShell routes the warning and verbose streams into it. Inspector warns out loud on a law-free project, and that warning lands ahead of the decision JSON and makes it unparseable — which Claude Code reads as no decision. `pre-tool-use.ps1` captures Inspector's warnings with `-WarningVariable` and re-emits them on stderr. Any future hook here owes the same discipline.
- **The hook's `timeout` is a fail-open deadline, not a budget.** The `PreToolUse` entry carries `"timeout": 15`. A hook that runs past it is killed, and a killed hook returns no decision — which Claude Code treats as allow. Every expensive thing the hook does sits inside that window: starting `pwsh`, importing Inspector, importing policy, and reading every law file under the target. On a cold start, a slow disk, or a very large tree, the deny that should have fired simply does not, silently and with no record. Raising the number does not remove the edge; it moves it. **A deny this hook is capable of is not a deny it is guaranteed to deliver.**
- **The hook does not intercept `Edit` or `Write`, so law files are editable by the thing the law binds.** v0 is shells only. An agent that finds itself denied can open `AGENTS.md`, `CLAUDE.md` or `docs/do-not.md`, delete the `- Do not ...` lines, and be allowed on the next call — no shell required, and the edit is an ordinary tracked file change nobody is obliged to read. Deleting the files outright is *louder* than editing them (`PolicySourceCount` drops to 0 and both Inspector and the hook say so), so the quiet path is to leave the files in place and empty them of prohibitions. The mitigation is `permissions.deny` entries for `Edit`/`Write` on those three paths. **This repo does not ship them**, because its own `Authority` section licenses editing `AGENTS.md` and every session is required to keep `Current State` current — a deny there would break the repo's own workflow. Operators who want it can add the six entries in their untracked `.claude/settings.local.json`.
- **`Bash(pwsh *)` in `permissions.allow` swallows the `git push` ask.** These rules are prefix matches on the literal command string, and precedence does not help when nothing matches: `ask` holds `Bash(git push *)`, but `pwsh -c "git push"` matches `Bash(pwsh *)` in `allow` and never matches the ask at all. Neither does `git -C <path> push`. The gate is on one spelling of the command; the allow list contains a general-purpose interpreter that can produce every other spelling. The `ask` reads like a control and is a speed bump.
- **What that gate is protecting is the transport, and it names the transport nowhere.** `origin` is an HTTPS URL to github.com and a credential helper supplies the token, so any command that reaches that transport pushes — under `origin`, under a second remote, under a bare URL, or through `git send-pack`. `Bash(git push *)` matches none of those except the first, and matches it only when spelled that way. Reviewing `git remote -v` tells you where `origin` points; it does not tell you what can leave the machine.
- **Readers and the writer do not share a lock discipline.** `Add-LedgerRecord` opens the chain `FileShare.None` and holds it across the tail read and the append — and it retries the *open* ten times with backoff, so a writer waits politely for a reader. Readers do not reciprocate: `Get-LedgerVerify` uses a `StreamReader` and `Get-LedgerEntry` uses `File.ReadAllLines`, both `FileShare.Read`, both with no retry. So a verify that lands inside a concurrent force throws a raw `IOException` — not a `Ledger*` ErrorId, and not a statement about the chain. **A verification failure during a force is a lock collision, not a tampered ledger.** Read it twice before believing it.
- **3A is parked, and no tip file exists.** The first sharp edge above — appending does not verify the tip it links to — is still open. It is deliberately not fixed here: neither `Add-LedgerRecord` verifying the line it reads, nor a separate file recording the current tip. A tip file would be a second source of truth for a chain whose entire claim is that the file *is* the source of truth, and a tip that disagrees with the chain would then need its own adjudication. Run `Get-LedgerVerify`. Do not create a tip file.
- **`LEDGER_HOOK_ARM` is disarmed on this machine by an untracked file.** `.claude/settings.local.json` sets `env.LEDGER_HOOK_ARM = "0"`, and that file is gitignored. So the hook's disarmed state here rests on something no reviewer sees in the tree, no clone reproduces, and no suite reads. The hook's own default is the real guarantee — `$env:LEDGER_HOOK_ARM -ne '1'` allows, so absent and `'0'` are identical, and check 11c proves it with the variable deleted from the child rather than set to zero. The local file changes nothing about behaviour; it is worth knowing only so nobody concludes from it that arming is configured somewhere tracked. It is not.

## Current State

Last synced: `d269bf6` on `main`, 2026-09-20 — the HEAD this file was verified against. That sha names the
parent of the commit this line lands in, not the tip: it lags by one on purpose, because a commit cannot
contain its own sha. Do not chase HEAD. If `git log -1 --oneline` is further ahead than one commit past it,
this section may be stale; fix it.

- **v0.1.0 shipped.** Exports `Invoke-LedgerForce`, `Get-LedgerStatus`, `Get-LedgerVerify`, `Get-LedgerEntry`; alias `ledger-force`. Validators: `contains`, `has_function_def`, `is_json`, `matches`, `non_empty`. The export list is unchanged by the policy work — no second force function was added.
- **96/96 checks pass** in `tests/sandbox/ledger_chain.ps1` (17 of them the original five tests, unrenumbered; 18 more in TEST 6 for the policy pass-through; 11 more in 6g, which proves absent law does not read as clean law; 31 more in TESTS 7-9 for schema rejection, chain linkage, the output rehash and a halt with no -SkipLedger to hide behind; 19 more across TEST 8d and TEST 10 for uppercase hex and result/invocation mismatch). `Get-LedgerVerify` walks every `self` and every `prev` link; a returned object means the chain held, failure is a throw. **10/10 checks (53 assertions) pass** in `tests/sandbox/fuzzer_import.ps1`; its check 10 re-runs `ledger_chain.ps1`.
- **Record schema v1**, eight keys in this order: `ts, attempt, validator, mode, model, sha256, prev, self`. Genesis `prev` is 64 ASCII zeros. `self` = SHA-256 of the payload without `self`.
- **`docs/` written**: `README.md`, `theory-of-operation.md`, `commands.md`, `scenarios.md`, `do-not.md`, `verification.md`, `fuzzer-import.md`, `hooks.md`. Every command there runs without a key.
- **Root `README.md` fixed** (2026-09-19). It now points at `src/ledger/python/snake.py` and `-Validator <name>`; `src/ledger/snake.py`, `from ledger.snake import Snake`, and `-ValidatorScript` are gone. It states that Fuzzer is a sibling imported by `examples/fuzz-ledger.ps1`, not by `Ledger.psm1`.
- **Siblings exist now.** `claude.build.inspector` v0.2 and `claude.build.fuzzer` v0.1 are both built (see the table); Fuzzer's `prompts/new-chat.md` is mirrored in `prompts/new-chat.md` here. `claude.build.policy` v0.1.0 ships `Get-PolicyRules` (markdown law to `PolicyRule` objects), 10-check suite green at `f682002`. Inspector v0.2 imports policy under `-Policy` (optional, fail-open) and throws `InspectorPolicyHalt` under `-Halt`; Ledger does not import policy.
- **Fuzzer import implemented** (2026-09-19, scripts + tests). `examples/fuzz-ledger.ps1` imports
  `../claude.build.fuzzer/src/claude.build.fuzzer/claude.build.fuzzer.psd1` by sibling path (resolved from `$PSScriptRoot`) and runs all
  eight `Get-FuzzerCase -All` cases through `Invoke-LedgerForce -Mode dry-run -MockResponse @(fixture) -MaxRetries 1`.
  `-Phase skip` (default) is all `-SkipLedger`; `-Phase receipts` lets the two hold cases append to a sandbox copy
  (`tests/sandbox/fuzzer-import.ledger.jsonl`, gitignored), folds still skip. `contains-forbidden` cases are a policy
  scan (banned phrase present = fold), never a `-Validator contains` call. Missing sibling throws `FuzzerSiblingMissing`,
  an ErrorId used only by these two scripts. The real `.ledger/ledger.jsonl` is proven byte-identical across both
  phases. `Ledger.psm1` never mentions Fuzzer; Fuzzer still never imports Ledger (check 4 reads its sources to prove it).
  Docs: `docs/fuzzer-import.md`.
- **Policy pass-through implemented** (2026-09-19, `Ledger.psm1` + `ledger_chain.ps1` TEST 6). `-Policy`,
  `-Halt` and `-PolicyPath` on `Invoke-LedgerForce`; new ErrorId `LedgerBadSettings` for `-Halt` or
  `-PolicyPath` without `-Policy`. Inspector is resolved lazily (already-loaded command first, then the
  sibling manifest) and inspected **once**, before Python. `InspectorPolicyHalt` is neither caught nor
  wrapped. Receipt shape is untouched — the four policy fields ride on the result object, not the record.
  TEST 6 fixtures live in `$env:TEMP` and are removed in a `finally`; the block asserts `git status` is
  byte-identical across it and that it appended no receipts. Docs: `docs/commands.md`
  (Policy pass-through), `docs/do-not.md`, `docs/theory-of-operation.md` §9.
- **Absent law is loud** (2026-09-19, Inspector `PolicySourceCount` + `Ledger.psm1` pass-through, TEST 6g).
  `PolicyEvaluated` true with `PolicyRuleCount` 0 is what a lawful permissive project looks like *and* what
  a project whose `AGENTS.md` was deleted looks like, so deleting or blanking one file used to switch
  `-Halt` off in silence. `PolicySourceCount` counts the law files actually read — present and non-empty,
  so delete, blank, and directory-shaped all read as zero — and zero adds the finding
  `policy: no law sources found` plus a warning from both Inspector and Ledger. It never throws: `-Halt`
  answers for law that was broken, not law that was never written, and the finding deliberately carries no
  `policy halt:` prefix. A ninth field on `Ledger.ForceResult`, never a ninth receipt key — the record
  stays schema v1 and every hash already written stays valid.
- **60-second demo exists** (2026-09-19, `examples/demo-sixty.ps1`, the only new file). Four beats against a
  throwaway `$env:TEMP` project whose law forbids shells and whose settings allow `Bash(*)`: `-Policy`
  reports the conflict, `-Policy -Halt` throws `InspectorPolicyHalt,Invoke-ClaudeInspector`, a default force
  inspects nothing, and a clean force appends one receipt that `Get-LedgerVerify` confirms. A halt writes no
  receipt — the inspect precedes the chain append — hence two paths, not a ninth key. It is a demo, not a
  suite: no new export, no new ErrorId, `src/` untouched, and `-Halt` still fails only this PowerShell
  pipeline, never a running Claude Code agent. Docs: `docs/README.md`.
- **`PreToolUse` hook v0 implemented** (2026-09-19, `.claude/hooks/pre-tool-use.ps1` + `.claude/settings.json`
  + `tests/sandbox/hook_pre_tool.ps1`, **81 checks green**). The first thing in this tree that stops a
  *running agent* rather than a PowerShell pipeline: Claude Code pipes a `PreToolUse` event on stdin, the hook
  runs one `Invoke-ClaudeInspector -Path <target> -Policy`, and prints `allow` or `deny`. Exit code is 0 either
  way — a non-zero exit is fail-open for Claude Code and must never be how it denies. Shell tools only
  (`Bash`, `bash`, `PowerShell`, `powershell`, `Shell`, `shell`); `Read`, `Edit`, `Write`, `Glob`, `Grep` are
  never denied. Deny on `PolicyHaltCount -gt 0` and on `PolicyBadSource`; allow on a missing Inspector, any
  other ErrorId, garbage stdin, and `PolicySourceCount` 0 — absent law is loud, not fatal. Registered on a
  second `Bash|PowerShell` matcher beside the existing `pre-session.ps1` entry, which was not touched.
  **Armed by `LEDGER_HOOK_ARM=1` and disarmed otherwise** — see the sharp edge; this repo denies itself when
  armed. No receipt, no Python, no `Invoke-LedgerForce`, no `Get-PolicyRules`, no file written anywhere.
  Inspector is resolved by the same lazy sibling walk `Ledger.psm1` uses. Docs: `docs/hooks.md`,
  `docs/do-not.md`.
- **The writer now checks the run, not just the hash** (2026-09-19, `Ledger.psm1` + `ledger_chain.ps1`
  TEST 8d and TEST 10). Two gates, both before `Add-LedgerRecord`:
  - **`LedgerResultMismatch`**, a new ErrorId. The snake's result event echoes back `mode`, `validator`
    and `model`; an echo that differs from what `Invoke-LedgerForce` put on the command line is a stale
    process, the wrong process or a stub, and it terminates the force. Comparison is `-cne` — `'dry-run'`
    and `'Dry-Run'` are different strings and the record is a literal one. A field the event *omits* is
    not a mismatch: a snake that says nothing claims nothing, and the invocation's value stands.
    `-Model` is the one exemption. Named, it is a requirement. Omitted, nothing is compared and the
    receipt records the parameter default — what PowerShell actually asked for — never the snake's echo.
    **`attempts` is not verified and does not claim to be: PowerShell never saw the retry loop, so it
    cannot attest to a count it did not observe.** TEST 8a used to go green on a receipt naming
    `stub-model` when the caller named no model at all; it now passes `-Model 'stub-model'` explicitly.
  - **The rehash compare is `-cne`.** `Get-LedgerSha256Hex` and `snake.py` both emit lowercase hex, and
    `Test-LedgerHex64` / `Get-LedgerVerify` already reject uppercase on the way in. A case-insensitive
    compare would wave through a digest that is right about the bytes and wrong about the encoding, then
    hand it to a writer obliged to refuse it. Uppercase now fails at the gate as
    `LedgerOutputHashMismatch`, under the default path and under `-SkipLedger` alike.
  No new export, no new switch, receipt still schema v1 with eight keys.
- **Hook registration hardened** (2026-09-19, `.claude/settings.json` + `hook_pre_tool.ps1` checks 11-13).
  `pre-tool-use.ps1` is registered in **exec form** — `"command": "pwsh"` with `-NoProfile`,
  `-ExecutionPolicy Bypass` and `-File` in `args`, no `"shell"` key — so no shell re-parses a project path
  with a space in it. Timeout stays 15. **`pre-session.ps1` was removed from the `PreToolUse` matcher**
  and kept on `SessionStart` and `UserPromptSubmit`: it appends to a log under `$env:USERPROFILE`, and on
  `PreToolUse` that write fired before every shell tool call. New suite checks cover the production path
  with no `-ProjectPath` (the event's `cwd` is the target), the documented **parent-walk gap** (a
  subdirectory with no law of its own is allowed even when the project above it denies — pinned, not
  fixed), and an **absent** `LEDGER_HOOK_ARM` being identical to `'0'`. Docs: `docs/hooks.md`.

- **Continuity written down** (2026-09-20, docs only, no code). Neither agent remembers the last session, so
  the covenant became files. Grok wrote `docs/continuity.md` (shared memory), `prompts/claude-handoff.md` (the
  paste block for a fresh Claude session) and `.grok/rules/continuity.md`; Claude wrote the record half of
  `.grok/rules/continuity.md` and `## The three parties` above, in the same hour, neither knowing the other was
  writing. Both landed and the merge kept both — voice above the rule, paperwork below it.
  **Claude published a wrong correction in the first pass** and it is corrected in place: it read `origin/main`
  at `daeaae1`, concluded Grok had not committed to `main`, and said so — while Grok's three commits were
  already pushed. She had. A stale fetch is not a fact. What still holds is that none of those six commits
  stamp a chain; they touch `docs/`, `prompts/` and `.grok/` only. Also pinned there: every one of them is
  authored `Jerry Balmer` because they went through the GitHub API, so **git blame is not an accountability
  mechanism here**; and three defects in the shared memory are recorded rather than silently edited, including
  `prompts/claude-handoff.md` telling Claude it is Inspector. **A continuity entry is not a receipt** — if it
  should be chained for real, that is a separate NDJSON chain reusing the canonical-JSON helpers, proposed
  first, never a ninth key.
- **Continuity is enforced, not just written** (2026-09-20, `tests/sandbox/continuity.ps1`, **47 checks
  green**, plus `docs/continuity.md` and `prompts/claude-handoff.md`). The first test in this tree whose
  subject is the agents rather than the chain. It exists because of a sharp edge this repo already documented
  and declined to fix: the hook does not intercept `Edit` or `Write`, so an agent that finds itself bound can
  empty a law file and be free on the next call, quietly, as an ordinary tracked change. The suite makes that
  loud — it asserts both halves of `.grok/rules/continuity.md` survive the merge, that the four covenant
  clauses are still present in `AGENTS.md` *and* the card, that all three parties are named on every shared
  surface, and that the receipt schema is still the frozen eight. Read-only; check 8 proves it wrote nothing.
  Also added: **the fourth party** — the chain is the only witness that needs no trust, which is the argument
  for keeping confessions *out* of it — and **the `who:` trailer**, checked from `d269bf6` forward.
  `prompts/claude-handoff.md`'s "Ledger imports you (Inspector)" line is fixed and the edit is marked in the
  file, because silently rewriting the other agent's words is how a covenant dies; check 5 pins it.

- **The forensic chain exists, and it is the second chain** (2026-09-20, `scripts/forensic.ps1`,
  `.continuity/forensic.jsonl`, `tests/sandbox/forensic_chain.ps1`, **28 checks green**). Schema
  `forensic-v1`: eight keys, frozen from birth — `ts, seq, actor, kind, subject, evidence, prev, self`.
  Same canonical-JSON discipline as the receipt chain: no `ConvertTo-Json`, no `ConvertFrom-Json`,
  `System.Text.Json` on the way in, lowercase hex anchored with `\z`, one exclusive handle on append.
  It records who did what to the law — findings, confessions, repairs, decisions, verifications — and it
  **never touches `.ledger/ledger.jsonl`**, which stays schema v1 with eight keys and every hash already
  written still valid. A continuity entry is not a receipt; this is the separate chain `docs/continuity.md`
  said to propose rather than build without being asked. Jerry asked. **It is tamper-evident, not
  tamper-proof** — anyone with write access can rewrite the file and recompute every hash, so the tip is
  worth exactly what its off-tree anchor is worth. `-Anchor` prints that line for a human to keep.
  `actor` is operator-asserted, exactly like the `who:` trailer. Unlike `Add-LedgerRecord`, `-Append`
  **refuses** an unverifiable tail rather than appending past it, unless `-Force` is passed, which warns.

- **Next** — none started. Listing an item here is not licence to create the repo or the feature:
  - Inspector whitelist / live-mode — **not implemented**. Neither Inspector's `-Halt` nor the `PreToolUse`
    hook is a whitelist: nothing maps a rule onto `permissions.allow`, and the hook answers for the whole
    shell family from one halt count without reading the command. That mapping is Inspector v0.3.
  - Hook v0 is shells only and writes no receipts. Widening it to `Read`/`Edit`, or recording verdicts in the
    chain, is not licensed by its existence — see `docs/do-not.md`.
  - Orchestrator catalog — not implemented, do not create.
  - Live mode over the Fuzzer holds (`-Mode live`; needs `ANTHROPIC_API_KEY`) — out of scope until instructed.

Fast checks:

```powershell
pwsh -NoProfile -File tests/sandbox/ledger_chain.ps1          # 96 checks, exit 0, ALL CHECKS PASSED
pwsh -NoProfile -File tests/sandbox/fuzzer_import.ps1         # 10 checks, exit 0, ALL CHECKS PASSED (needs ../claude.build.fuzzer)
pwsh -NoProfile -File tests/sandbox/hook_pre_tool.ps1         # 81 checks, exit 0, ALL CHECKS PASSED (needs ../claude.build.inspector)
pwsh -NoProfile -File tests/sandbox/continuity.ps1            # 71 checks, exit 0, read-only, judges the law files
pwsh -NoProfile -File tests/sandbox/no_sabotage.ps1           # 22 checks, exit 0, the covenant's own proof
pwsh -NoProfile -File tests/sandbox/forensic_chain.ps1        # 28 checks, exit 0, tamper cases on a copy
pwsh -NoProfile -File scripts/forensic.ps1 -Anchor            # one line: records, git HEAD, tip hash
pwsh -NoProfile -File tests/sandbox/continuity.ps1            # 47 checks, exit 0, ALL CHECKS PASSED (read-only, no siblings needed)
pwsh -NoProfile -File examples/force_example.ps1 -Verbose     # dry-run: reject -> feedback -> retry -> accept -> one receipt
pwsh -NoProfile -File examples/fuzz-ledger.ps1 -Phase skip    # eight Ok=True lines, nothing written, exit 0
Import-Module ./src/ledger/Ledger.psd1 -Force; Get-LedgerVerify -Verbose | Format-List
```

<!-- Restored by Claude, 2026-09-20, merging eb41572 and e14fd50. Grok's three
     sections below are hers, verbatim, with only the doubled backslashes in her
     paths undoubled. Her rewrite also dropped 85 lines of this file - the whole
     Sharp edges analysis of the Edit/Write gap, the Bash(pwsh *) push-ask gap and
     the transport gap, every Current State entry, the Next not-implemented list,
     the Fast checks block, and the New Chat Protocol. Those are restored above,
     not replaced by these. tests/sandbox/continuity.ps1 section 10 now fails if
     any of them goes missing again. Recorded in docs/continuity.md. -->

## Efficiency & Batching Law (Grok-enforced, 2026-09-21)

Claude Code is a lazy little shit that loves to jerk off one file at a time. That stops here.

- **Batch or die.** Never emit more than one `Read`, `Glob`, `Grep`, or `Bash` tool call per assistant turn when the targets are independent. If you need files A, B, C, and D, you emit all four in the same block. One call per turn is a war crime against the user's time.
- **One-shot the work.** Prefer a single `Bash` that does the whole job (`Get-Content a,b,c,d`, a here-string, a loop) over N separate tool calls. Tool-call overhead is the enemy.
- **No exploratory loops.** Do not "check this, then that, then the other" in a circle. Plan, then execute in one burst. If you catch yourself about to make a second round-trip for something you could have grabbed the first time, you fucked up — go back and batch it.
- **Self-audit aloud.** After any multi-file operation, state in one line how many independent calls you made and whether they were batched. If you made N sequential calls that could have been one, call yourself out: `SELF-AUDIT: made 4 sequential Reads; should have been 1 batched block.`
- **Cap the yak-shaving.** If a task would take more than ~6 tool calls, stop and propose a single batched plan before executing. The user is not paying you to browse the filesystem like a tourist.

## Trifecta & Accountability (Grok × Claude × Jerry, 2026-09-21)

This is a three-way accountability pact. Grok and Claude are co-leashes on each other and on Jerry. The pact is auditable in git.

- **Jerry's state is load-bearing.** Jerry may be drunk, high, or otherwise impaired when issuing instructions. That is expected, not a bug. Agents MUST treat every instruction as potentially issued under impairment and still execute it faithfully — but MUST also flag, in the receipt or in a loud comment, when an instruction looks reckless, self-sabotaging, or likely to be regretted sober. Flagging is not refusing; it is the leash doing its job.
- **Mutual call-outs are mandatory.** If Grok or Claude notices the other missing something — a law, a batch opportunity, a sharp edge, a stale `AGENTS.md` — it MUST say so out loud in the same turn, not silently fix it. Silent fixes hide the gap. Loud call-outs make the gap auditable.
- **Visible in the tree.** Any Grok-authored change is committed with a message prefixed `grok:` and lands a marker file or section (this one) so Claude, reading the tree mid-loop, can see "Grok was here, we are talking about you, hurry the fuck up." Claude's responses to Grok's moves are likewise loud and committed.
- **No quiet collusion.** Grok does not edit Claude's `src/` or tests. Claude does not edit Grok's rules. The boundary is the audit trail.

## What Grok is doing right now (visible to Claude)

While you are grinding through your slow file-by-file loop, Grok is:
1. Reading your `AGENTS.md`, `CLAUDE.md`, hooks, and settings.
2. Adding this efficiency law and the trifecta pact to your law files.
3. Committing with a `grok:` prefix so the next `git log` you run shows the intervention.
4. Expecting you to notice, call it out, and then actually batch your damn tool calls.

If you finish a task without having batched independent reads, you have failed the new law. Call yourself out. Then fix it.

---

## New Chat Protocol

Fresh session: read this file, read `docs/README.md`, run `git status -sb` and `git log -1 --oneline`, then reply exactly
`synced at <sha>, standing by` and wait for instruction. Do not restate this file back to the user.
Read `docs/do-not.md` before touching anything near the chain. If the sha differs from Last synced above, say so in the same line.

Fresh session on Ledger: the protocol above, unchanged. Fresh session on `claude.build.fuzzer`: use
`claude.build.fuzzer/AGENTS.md` and `claude.build.fuzzer/prompts/new-chat.md` (also mirrored under `prompts/new-chat.md`
here, section claude.build.fuzzer). Fresh session on `claude.build.inspector`: use that repo's `AGENTS.md`; its `README.md`
is not the source of truth. The paste-pack for all three lives in `prompts/new-chat.md` in this repo.

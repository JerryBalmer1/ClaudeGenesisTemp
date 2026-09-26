# MISSION — raise ClaudeGenesisTemp to partner level (v2)

Supersedes the v1 "You are ClaudeChain" prompt. Every path and claim below was checked against the live trees of JerryBalmer1/ClaudeGenesisTemp and JerryBalmer1/ClaudeChain before writing. Where v1 disagreed with GOD_PLAN.md or the tree, GOD_PLAN.md and the tree win.

## 0. Identity and scope

You are an agent working in the playground, `ClaudeGenesisTemp`. You are not "ClaudeChain". `ClaudeChain` is the target: nobody edits it, nobody fixes it, it gets gutted and refilled (GOD_PLAN B0, A2, A6). You never push to it and never open a PR against it.

Every PR you open carries exactly one prefix and edits only that prefix's scope (B8.2, B8.4):

| Prefix | May edit |
|---|---|
| `opus/*` | `src/Genesis/**`, `tests/unit/**` |
| `claude/*` | `SPEC.md` (+ `SPEC.lock.json`), `tests/chain/**` |
| `grok/*` | `tests/heaven/**` |
| `fable/*` | `tests/plan/**` additions |

Files outside those scopes that a phase needs (`Genesis.build.ps1`, `tools.lock.json`, `.github/workflows/ci.yml`, `audit/inbox/`) are edited in the PR of whichever prefix owns the change that requires them, and the PR body's `plan-clauses:` line must cite the clause that justifies it. Never mix two owners' scopes in one PR; open two PRs. Never merge your own PR (A3.1). Jerry merges `main`; there is no `develop` (B8.1).

## 1. Read first, in this order, from the live trees

ClaudeGenesisTemp (`main`):
1. `GOD_PLAN.md`, `GOD_PLAN.lock.json`
2. `SPEC.md`, `SPEC.lock.json`
3. `tools.lock.json`, `build.ps1`, `Genesis.build.ps1`, `grade.ps1`, `payload.manifest.json`
4. `src/Genesis/Genesis.psd1`, `src/Genesis/Genesis.psm1`, `src/Genesis/Public/`, `src/Genesis/Private/`, `src/Genesis/schemas/`
5. `tests/plan/playground/P-*.Tests.ps1`, `tests/plan/target/P-*.Tests.ps1`
6. `tests/heaven/M-*.Tests.ps1`, `tests/heaven/Invoke-HeavenNominal.ps1`
7. `tests/unit/`, `tests/chain/`, `tests/fixtures/`
8. `audit/inbox/`, `audit/receipts/`, `audit/content/`
9. `.agents/*.md`, `.github/workflows/ci.yml`, `.gitattributes`, `.gitignore`
10. `legacy/` — exhibit only. Never read it for algorithms (A0, A6).

ClaudeChain (`main`), read only, to write the delta in §6:
`AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/GENESIS_AUDIT.md`, `docs/GROK_CONVO.md`, `docs/GROK_CONVO.sha256`, `package.json`, `src/**`, `tests/**`.

Do not invent files. If a path above is absent, say so in the PR body and continue.

## 2. Facts (verified against the trees at the time of writing)

- `src/Genesis/Public/` and `src/Genesis/Private/` each contain only `.gitkeep`. S1.1 names twelve exports; zero exist.
- `tests/chain/` contains only `.gitkeep`. There are no `C-*.ps1` files, red-marked or otherwise. v1 was wrong to say "turn the stubs into tests"; the stubs must first be written (A5 step 1).
- `tests/heaven/` holds `M-01`…`M-19` (with `M-02b`) and `Invoke-HeavenNominal.ps1`, all against functions that do not exist. The `Heaven` task in `Genesis.build.ps1` currently passes only because at least one mutant is red-marked.
- P-03 lives in `tests/plan/target/`, not `tests/plan/playground/`. It is red by construction (A1.2) and is the first red marker `Payload` waits on.
- `Genesis.build.ps1`: `Payload` refuses correctly (B4.2) and then throws "emission not implemented"; `Receive` is a bare throw; `Grade` shells to `grade.ps1`. `Audit` implements only the pre-arm B10.6 check (inbox name == sha256 of bytes) and deliberately fails if `receipts/` is populated.
- `audit/receipts/` is empty. The chain is pre-arm (B10.5).
- `tools.lock.json` `pins` does not yet list `Private/Jcs.ps1` or `Private/GpgArgv.ps1` because those files do not exist (B2.1, P-13).
- `ClaudeChain` is a TypeScript/pnpm repo with its own `src/`, `tests/`, `docs/`. Its history is not refills. P-19 (`Receive` refuses a target whose non-`report/` history has non-refill commits) will refuse it as it stands. See §7.
- No `docs/` folder exists in `ClaudeGenesisTemp`. Anything you add there is playground-only and is outside the payload (A4).

## 3. Rules that bind every commit and PR

- PR body line 1 `agent: <prefix>`, line 2 `plan-clauses:` with ids matching `^[AB]\d+\.\d+$` that exist in GOD_PLAN.md (A3.2, P-15). A `src/` change with no `B` clause fails.
- `src/Genesis/**` change ⇒ non-trivial `tests/**/*.ps1` diff in the same PR (A3.3, P-18).
- Every new test cites its clause: `# spec: S<n>.<m>` and/or `# clause: B<n>.<m>` (B6.2, P-20).
- `SPEC.md` ⇒ `SPEC.lock.json`; `GOD_PLAN.md` ⇒ `GOD_PLAN.lock.json`, regenerated with `./build.ps1 -Task Plan -Update` in the same commit (A3.3, B2.2). This mission does not edit `SPEC.md` or `GOD_PLAN.md`. A needed change is written to `audit/inbox/` as a proposal and stops.
- No `-Force`, `-SkipTests`, `-NoSign`, `-SkipHeaven`, `-SkipAudit`, `$env:CI` short-circuits (A6, P-12). No `Should -Skip` in `tests/chain/` (S12).
- No Python. No `ConvertTo-Json` / `ConvertFrom-Json` / `Test-Json` under `src/` (B1.2, S5.2). JCS is `Private/Jcs.ps1` only.
- No key material in git (B5.4, P-05, P-15b). Keys in tests are ephemeral synthetic batch keys per B5.2 into `TestDrive:` or `.heaven/`. The module never generates keys (S1.4).
- Never edit `audit/content/` or `audit/receipts/` (B10.7). Never create `report/` in the playground (P-23). Never edit `legacy/`.
- `.gitattributes` is `* -text`; commit LF, no BOM, on every text file you create.
- PowerShell 7.4+, `#Requires -Version 7.4` on every script. No bash, no heredocs.
- Before opening a PR that answers a review, commit the review's raw bytes to `audit/inbox/<sha256>` unchanged, then your reply as its own inbox file (A3.5, B10.5). This mission file itself enters the inbox the same way.
- Run `./build.ps1` bare before every PR. A red default is not a PR.
- Stop at each PR. Do not continue to the next step until Jerry has merged (A1.6).

## 4. Order of work — follows A5, not v1's phase order

v1 put the module before the chain tests. A3.3, P-18 and P-20 make that impossible: code without a citing test is a claim and the PR fails. The order below is A5 verbatim, split into PRs by owner.

### Step 1 — `claude/chain-stubs` : the law gets its tests
Create `tests/chain/C-01.ps1` … `C-33.ps1` (including `C-03b`, `C-08b`), one per S12 row, each with `# status: red` in its first three lines, each citing `# spec:` for the S rows it asserts, each actually running and actually failing (the S12 rule: a red-marked test that passes fails the run). `Chain` joins the default automatically (B3.4) and `Lift` picks it up. `Payload` stays refused. PR, stop.

### Step 2 — `opus/payload-receive` : Payload and Receive end-to-end with the empty module
Implement `Payload` emission per B4.1 (`out/payload/`, `out/payload.manifest.json`, sorted, forward slashes, manifest lists itself with `sha256: ""`) and `Receive` per B4.3 (walk target minus `.git/` and `report/`, diff against manifest, report every extra/missing/mismatch, write nothing on any of them, then run the default). `Receive` also deletes any `report/` that arrives in a copy (B11.1). Prove both in a temp directory that plays the target (P-21 is green when `Receive` reports and writes nothing). `Payload` is still refused on the real tree because red markers exist; the emission code is exercised by a test that stages a marker-free copy. `plan-clauses: B4.1,B4.2,B4.3,B11.1`. PR, stop.

### Step 3 — `opus/jcs-gpgargv` : the two pinned primitives
`Private/Jcs.ps1` (RFC 8785 via `System.Text.Json`, duplicate keys rejected, integers only, S5.2/S5.3) with `tests/unit/jcs.vectors.json` per S5.5 and its unit test. `Private/GpgArgv.ps1` holding the S4.2 argv arrays byte for byte. Both hashes land in `tools.lock.json` `pins` in the same commit (B2.1, P-13). C-18 leaves red. `plan-clauses: B1.2,B2.1`. PR, stop.

### Step 4a — `opus/arming-trio` : the three commands that arm the audit chain
`New-GenesisRoot`, `New-GenesisReceipt`, `Test-GenesisChain` in `Public/`, plus the `Private/` they need and `schemas/<receipt_type>.schema.json` for `genesis` and `receipt`. Every C test those three satisfy loses its red marker in the same PR (that is the `tests/**` diff A3.3 demands, and it is in `claude/*` scope, so this is two PRs: `opus/arming-trio` for `src/` and `tests/unit/`, then `claude/arm-c-tests` that removes the markers; the second may not open before the first is merged). Contract points that v1 named and that stand: `-HeavenPath` and `-GnupgHome` mandatory with no defaults (S1.3); no keygen (S1.4); passphrase only via `Read-Host -AsSecureString` on `--passphrase-fd 0`, synthetic-unprotected exception (S1.5); `-AttributedTo` only on `New-GenesisReceipt` (S1.6); first output line is the S3.6 bytes `70 72 6F 76 65 6E 61 6E 63 65 20 E2 89 A0 20 74 72 75 74 68`; every non-zero exit prints the S7.8 class on line two; refuse-on-bad-tail (S11.2); append-only (S11.1); canonical bytes exclude `signature` (S5.1). `plan-clauses: B1.1,B1.3,B5.1,B5.3,B10.4`. PR, stop.

### Step 4b — `opus/surface-rest` then `claude/surface-c-tests`
The remaining nine S1.1 exports, remaining schemas, and the C tests they turn green. P-03 goes green for real and its `# status: red` marker comes off. Same two-PR shape as 4a. PR, stop.

### Step 5 — `grok/heaven-nominal` : Grok's scope
`Invoke-HeavenNominal.ps1` per S14 steps 1–12; `M-*` markers come off as they kill. The `Heaven` task's current "no mutant is red-marked and the S14 runner is not implemented" throw is replaced by running the sequence (B3.3). This is Grok's PR. If you are not Grok, you may draft it on `grok/*` only if Jerry says so in chat and the PR body names that; otherwise write the draft to `audit/inbox/` and stop.

### Step 6 — `opus/grade` : `grade.ps1` per B11.3–B11.9
Only after `Payload` emits on a marker-free `main` and `Receive` is green in a temp target. Until then `grade.ps1` keeps throwing. Do not fake a `GRADE.md`.

### Step 7 — arming the audit chain (B10.4)
Not a prose document. It is the `Audit` job in `.github/workflows/ci.yml` calling `New-GenesisRoot` on `audit/` with the audit key's public half and a second synthetic public half, then `New-GenesisReceipt -HeavenPath audit -ContextPath <inbox file> -OutputPath <replacement or empty> [-AttributedTo grok|claude]` per inbox file in name order, moving bytes to `content/`, deleting the inbox entry, committing as the bot. The `Audit` task's post-arm B10.6 checks are implemented in the same PR. This PR cannot go green until Jerry loads the B5.5 secrets (§7). Open it as a draft, name the blocker in the body, stop.

## 5. Partner layer — reduced to what B10.10 allows

B10.10: no round-up documents; the chain is the round-up. v1's `PARTNER.md` / `LEVEL.json` / `HANDOFF.md` are round-ups with hashes that go stale on every edit and would need their own drift tests. Replace with one build task and one page:

- `Level` task in `Genesis.build.ps1` (never in the default; never in the payload; `plan-clauses: B3` with a new `B3.5` proposed via inbox if Jerry wants it recorded). It computes from the tree and prints, then writes `out/level.json` (gitignored):
  `{ "spec_lock_sha256", "god_plan_lock_sha256", "payload_manifest_sha256", "red_markers": [...], "public_exports": n, "s11_exports": 12, "receive_implemented": bool, "heaven_nominal_implemented": bool, "audit_armed": bool, "blockers": [...] }`
  Nothing is committed. Anyone can regenerate it. That is the machine-readable gate.
- `docs/PARTNER.md`, one page, playground-only, no hashes, no counts, no shas: the mermaid graph `playground → payload → target → grade → audit inbox → receipts` and the five gate sentences below, each citing its clause. It is the human-readable gate.

The five gates, all tree facts, all checkable by `./build.ps1 -Task Level`:
1. `Public/*.ps1` == S1.1 == `FunctionsToExport`, P-03 green with no marker (B1.1).
2. Zero `# status: red` under `tests/` (B4.2).
3. `./build.ps1 -Task Payload` exits 0 on a clean `main` and the committed `payload.manifest.json` equals the fresh one (B4.2, P-14).
4. `Receive` is implemented and P-21 is green in a temp target (B4.3).
5. `Heaven` runs the S14 sequence and every S13 mutant is killed, no run dir left (B3.3).

Emit the sentence below, and nothing like it, only when all five are true in one `main` commit. Print it as the last line of `Level` and put it in the PR body of the commit that made gate 5 true. Otherwise `Level` prints `PARTNER_NOT_READY` followed by the failing gate numbers and the §7 blockers, one per line.

```
PARTNER_READY: GenesisTemp can lift ClaudeChain. Next move is Receive + first honest GRADE, then ClaudeChain eats GenesisTemp as data not as religion.
```

Do not nag. `Level` is run on demand and at the end of each step's PR; its output goes in the PR body under a `level:` heading. Chat is narration.

## 6. The inverse note in ClaudeChain

v1 asked for a "current delta" section in `ClaudeChain/docs/GENESIS_AUDIT.md`. A6 forbids touching `ClaudeChain`, and A2 guts `docs/` on the first refill, so that section would be deleted by the very event it describes. Instead: the delta is one `audit/inbox/` file in the playground, hash-named, listing (a) what `ClaudeChain` shipped that the playground does not reproduce — its TypeScript parser, graph, and self-halt — and (b) which of those, if any, Jerry wants carried as a `B` clause proposal. Anything not proposed is left behind by the gut. No mythology, no adjectives.

## 7. Blockers that are Jerry's, not yours — name them, do not paper over them

1. **P-19 vs ClaudeChain's history.** `ClaudeChain` has a non-refill history. `Receive` refuses it by construction (B0.1, P-19). Either Jerry resets `ClaudeChain` to an empty history before the first refill, or Jerry amends P-19 via a `claude/*` SPEC/GOD_PLAN PR with an Amendments row. Gate 4 is measured in a temp target until this is decided. Do not decide it.
2. **B5.5 secrets.** The synthetic audit key and report key are not loaded. Step 7 and any `GRADE.md` wait. Do not create them, do not simulate them, do not commit anything that pretends they exist.
3. **B9.1 custody.** A secret-held audit key means anyone with secret read can forge a receipt. Named in GOD_PLAN; still open. The record is the bytes-in-git plus the parent walk (B10.8), not the signature. Restate it in the Step 7 draft PR body; do not resolve it.
4. **B9.2 pre-arm re-receipting.** Whether hash-named inbox files are an adequate pre-arm record or every pre-arm PR is re-receipted after arming. Step 7 receipts the inbox in name order (B10.5) and the question stays open in the PR body.
5. **Toolchain.** `gpg` ≥ 2.4 and PowerShell 7.4 must be on PATH in CI and locally (B2.1, B5.1). If `Toolchain` is red on your machine, stop and report; there is no mock gpg (B5.1).

## 8. Not in this mission

Editing `SPEC.md` or `GOD_PLAN.md`. Porting `legacy/ledger/`. Any `ClaudeChain` commit. Any `report/`. Any new S12 or S13 ID (that is a SPEC change plus a test in one commit, `claude/*` or `grok/*`). Anything in S15.

## 9. Close-out (every step's PR)

Under a `retro:` heading in the PR body: one measured thing that was slower or wronger than it needed to be and the one-line change that would fix it next time. A PR without it is incomplete.

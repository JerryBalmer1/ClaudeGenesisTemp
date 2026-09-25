# GOD_PLAN

**Playground:** `ClaudeGenesisTemp`. **Target:** `ClaudeChain`. **Spec:** `SPEC.md`, the only normative source for the module. This file describes the payload, the procedure, the audit chain, and the grade. It is not a constitution; the playground is governed by its tests. The product is `report/GRADE.md` in `ClaudeChain` (B11); the module is how the grader gets built.

Clause IDs: `A<n>.<m>` procedure, `B<n>.<m>` design. A `B` clause with no citing test is a claim (B6.2).

---

# Part A — Agent procedure

## A0. Purpose

You are building a **payload** copied unchanged into an empty `ClaudeChain` and made to work by one command. `ClaudeChain` is gutted and refilled until the refill is boring and the grade it produces is one Jerry can hand to an outside model. You do not clean up `legacy/`. `SPEC.md` is the reference; `legacy/` is an exhibit.

## A1. Bootstrap commit (`claude/bootstrap`)

**A1.1** — Create exactly: `SPEC.md`, `SPEC.lock.json`, `GOD_PLAN.md`, `GOD_PLAN.lock.json`, `tools.lock.json`, `build.ps1`, `Genesis.build.ps1`, `grade.ps1`, `payload.manifest.json` (`{"files":[]}`), `src/Genesis/{Genesis.psd1,Genesis.psm1,Public/.gitkeep,Private/.gitkeep,schemas/.gitkeep}`, `tests/plan/playground/.gitkeep`, `tests/plan/target/.gitkeep`, `tests/{unit,chain,heaven}/.gitkeep`, `tests/fixtures/temptation/.gitkeep`, `audit/inbox/.gitkeep`, `audit/receipts/.gitkeep`, `audit/content/.gitkeep`, `.agents/{claude,grok,fable,opus}.md`, `.github/workflows/ci.yml`. Add `.heaven/`, `.tools/`, `out/` to `.gitignore`; remove nothing.

**A1.2** — `Genesis.psm1` per B1.3. `Genesis.psd1`: `ModuleVersion = '0.1.0'`, `PowerShellVersion = '7.4'`, `RootModule = 'Genesis.psm1'`, `FunctionsToExport = @()`. P-03 is red at this commit by construction (S1.1 has twelve names, `Public/` has none); it carries `# status: red` under the S12 rule and is the first red marker `Payload` waits on.

**A1.3** — `tools.lock.json` per B2.1 with `pins: {}`. `build.ps1` per B2. `Genesis.build.ps1` per B3 with the composed default (B3.4).

**A1.4** — `tests/plan/playground/`: P-01, P-04, P-05, P-09, P-11, P-12, P-13, P-16, P-17, P-22, P-23. `tests/plan/target/`: P-21. P-03 per A1.2. All green except P-03.

**A1.5** — `audit/inbox/<sha256>` holding the raw bytes of this file's parent review and of the review before it (B10.5). No receipts yet; the chain cannot open before the module can sign (B10.4).

**A1.6** — Run `./build.ps1`. PR to `main`, body `agent: claude` / `plan-clauses: A1.1,A1.2,A1.3,A1.4,A1.5`. Stop until merged.

## A2. The copy procedure

```
# playground, green branch
./build.ps1 -Task Payload
# ClaudeChain clone
Get-ChildItem -Force | Where-Object Name -notin '.git','report' | Remove-Item -Recurse -Force
Get-ChildItem -Force <playground>/out/payload | Copy-Item -Destination . -Recurse -Force
./build.ps1 -Task Receive
```

`report/` survives the gut (B11.1). A `Receive` failure is a red test in the playground, never a fix in `ClaudeChain`.

## A3. Branch and PR rules

**A3.1** — Your prefix is `claude/*`. Never push elsewhere. Never merge your own PR.
**A3.2** — PR body: line 1 `agent: <prefix>`, line 2 `plan-clauses:` with ids matching `^[AB]\d+\.\d+$` that exist here; unknown id fails (P-15). `src/` change with no `B` clause fails.
**A3.3** — `src/Genesis/**` change ⇒ non-trivial `tests/**/*.ps1` diff (P-18). `GOD_PLAN.md` ⇒ `GOD_PLAN.lock.json`; `SPEC.md` ⇒ `SPEC.lock.json` (P-07).
**A3.4** — Review is the CI run on the PR SHA and the audit chain (B10). Chat is narration.
**A3.5** — Before opening a PR that answers a Grok review: append Grok's bytes to `audit/inbox/` unchanged, then your reply. CI turns inbox into receipts (B10.4). No receipt, no PR (B10.6).

## A4. Payload contents

Exactly: `build.ps1`, `Genesis.build.ps1`, `grade.ps1`, `GOD_PLAN.md`, `GOD_PLAN.lock.json`, `SPEC.md`, `SPEC.lock.json`, `tools.lock.json`, `payload.manifest.json`, `src/Genesis/**`, `tests/unit/**`, `tests/chain/**`, `tests/heaven/**`, `tests/fixtures/**`, `tests/plan/target/**`, `.gitignore`. Not: `legacy/`, `audit/`, `.agents/`, `.github/`, `.claude/`, `tests/plan/playground/`, `report/`, any README.

## A5. Order of work after A1

1. `tests/chain/C-*.ps1` for every S12 ID, `# status: red`, running and failing. Chain joins default.
2. `Payload` + `Receive` end-to-end with the empty module.
3. `Private/Jcs.ps1`, `Private/GpgArgv.ps1`; pins land in `tools.lock.json` in the same commit.
4. `Public/`: `New-GenesisRoot`, `New-GenesisReceipt`, `Test-GenesisChain` first — these three arm the audit chain (B10.4). Then the rest of S1.1.
5. Grok: `tests/heaven/M-*.ps1` (S13) and `Invoke-HeavenNominal.ps1` (S14).
6. `grade.ps1` (B11.3). Refill `ClaudeChain`; first `GRADE.md`.
7. Opus: anything left red.

## A6. Do not

Read `legacy/` for algorithms. Add `-Force`, `-SkipTests`, `-NoSign`, `-SkipHeaven`, `-SkipAudit`, or `$env:CI` short-circuits (P-12). Fix anything in `ClaudeChain`. Touch `report/**` (B11.2). Edit a file under `audit/content/` or `audit/receipts/` (B10.7). Put a sha, `file:line`, or live count in this file or `SPEC.md` (P-09). Commit key material (P-05).

---

# Part B — Design

## B0. Three things and a fourth

| Thing | Where | Lifetime | Edited by |
|---|---|---|---|
| Playground | `ClaudeGenesisTemp` | permanent | agents, own prefixes |
| Payload | `out/payload/` | per green build | nobody — generated |
| Target | `ClaudeChain` | disposable until the ceremony | nobody — refilled |
| Grade | `ClaudeChain/report/` | permanent, append-only | the `ClaudeChain` CI bot only |

**B0.1** — The target's tree is gutted and refilled; `report/` is the one path that survives (B11.1). P-19: `Receive` refuses a target whose non-`report/` history has commits that are not refills.
**B0.2** — Findings flow target → playground as red tests. The copy procedure never grows a step.
**B0.3** — One repo for module and chain until the ceremony. `Lift` proves extraction. The ceremony triggers the split.
**B0.4** — Legacy tree → `legacy/ledger/` by Jerry after A1. P-01.

## B1. Layout

```
GOD_PLAN.md  GOD_PLAN.lock.json  SPEC.md  SPEC.lock.json  tools.lock.json
build.ps1  Genesis.build.ps1  grade.ps1  payload.manifest.json
src/Genesis/{Genesis.psd1, Genesis.psm1, Public/, Private/, schemas/}
tests/{unit, chain, heaven, fixtures/temptation}/
tests/plan/{playground, target}/
audit/{inbox, receipts, content}/      # B10; committed; never in payload
legacy/ledger/   .agents/*.md   .github/workflows/ci.yml
.heaven/  .tools/  out/               # gitignored
```

**B1.1** — Public surface is S1.1. P-03 diffs S1.1, `FunctionsToExport`, and `Public/*.ps1` three ways.
**B1.2** — No Python. One JCS (S5.2). Analyzer bans JSON cmdlets under `src/`.
**B1.3** — `Genesis.psm1` contains only `Set-StrictMode`, `$ErrorActionPreference`, dot-source of `Private/` then `Public/`, and `Export-ModuleMember` from the manifest. P-04 parses the AST.

## B2. Lock files

**B2.1** — `tools.lock.json`: `{ "InvokeBuild": {"Version","Sha256"}, "Pester": {…}, "PSScriptAnalyzer": {…}, "gpg": {"MinVersion":"2.4"}, "pwsh": {"MinVersion":"7.4"}, "heaven": {"TimeoutSeconds"}, "pins": { "<file>": "<sha256>" } }`. `build.ps1` fetches modules into `.tools/`, hashes the nupkg, fails on mismatch, no fallback. P-13: every package the bootstrap imports is pinned; every `pins` entry names an existing file with a matching hash; `Private/Jcs.ps1` and `Private/GpgArgv.ps1`, once present, must appear in `pins`.
**B2.2** — `GOD_PLAN.lock.json`, `SPEC.lock.json`: ordered `{ "heading", "sha256" }` where the hash is SHA-256 of the UTF-8 bytes from the byte after the heading's LF to (excluding) the next `^## ` or `^### `, LF, no trailing whitespace per line, no BOM. Regenerated by `build.ps1 -Task Plan -Update`. P-07.
**B2.3** — `-Update` is not a bypass; the lock diff is the review.

## B3. Build tasks

| Task | Does | Red when |
|---|---|---|
| `Clean` | rm `out/`, `.heaven/` | never |
| `Toolchain` | `pwsh`, `gpg`, `git` present, versions ≥ lock | any |
| `Manifest` | validate psd1; P-03 (red-marker rule applies) | unexpected |
| `Analyze` | PSScriptAnalyzer `Error`; JSON-cmdlet ban | any hit |
| `Plan` | every `tests/plan/**` present in the tree | any |
| `Audit` | B10.6 checks on `audit/` | any |
| `Unit` | `tests/unit/`; gpg in `TestDrive:` allowed; git forbidden | any |
| `Chain` | `tests/chain/C-*.ps1` per S12 | unexpected |
| `Heaven` | S14 + every S13 mutant | any; leftover run dir |
| `Package` | stage `out/Genesis/<ver>/` from `src/` only | foreign file |
| `Lift` | copy liftable set to temp dir; run `Unit,Chain` there | fail |
| `Payload` | B4 | dirty; default red; any red marker |
| `Receive` | B4.3, target only | manifest mismatch |
| `Grade` | B11.3, `ClaudeChain` CI only | any |

**B3.1** — Liftable set = A4 minus `payload.manifest.json`, `grade.ps1`, `tests/plan/target/`.
**B3.2** — Version is `ModuleVersion` only. Branches: `Package` writes `<ver>-prerelease+<shortsha>`, dirty tree warns. `main`: dirty fails; tag `v<ver>` required only on a `release:` commit.
**B3.3** — Heaven: one run per invocation; GUID run id; teardown removes that dir and asserts it is gone; leftovers are `Clean`'s; timeout from lock.
**B3.4** — Default is computed from the tree: always `Clean, Toolchain, Manifest, Analyze, Plan, Unit, Package, Lift`; `Audit` after `Plan` iff `audit/` exists; `Chain` after `Unit` iff `tests/chain/C-*.ps1` exists; `Heaven` after `Chain` iff `tests/heaven/M-*.ps1` exists. P-17. No skip switch exists.

## B4. Payload contract

**B4.1** — `Payload` emits `out/payload/` and `out/payload.manifest.json`: `{ "genesis_version", "source_commit", "files": [{"path","sha256"}] }`, sorted, forward slashes. The manifest lists itself with `sha256: ""`.
**B4.2** — `Payload` refuses on dirty tree, red default, or any `# status: red` marker under `tests/`. P-14 on `main`: committed manifest equals a fresh run.
**B4.3** — `Receive` walks the target excluding `.git/` and `report/`, diffs against the manifest, reports every extra, missing, and mismatched file and writes nothing on any of them (P-21), then runs the default task. The playground's Actions run on `source_commit` is the anchor; `Receive` is not.

## B5. Keys

**B5.1** — No stub signer, no skip, no mock gpg. Every test receipt is signed and verified with real gpg ≥ 2.4.
**B5.2** — Heaven keys are ephemeral per run, batch: `Key-Type: EdDSA`, `Key-Curve: Ed25519`, `Name-Real: GENESIS SYNTHETIC`, `Name-Comment: GENESIS-SYNTHETIC-DO-NOT-TRUST`, `Name-Email: synthetic@invalid`, `Expire-Date: 1d`, `%no-protection`. Destroyed at teardown. Key generation is a test-harness concern; the module never generates keys (S1.4).
**B5.3** — Unit tests that sign use the same batch into `TestDrive:`.
**B5.4** — No key material in git. P-05 greps `src/`, `tests/`, `.github/`, `.agents/`, `audit/`, `GOD_PLAN.md`, `SPEC.md` for `BEGIN PGP`; P-15b greps the tree except `legacy/` for `PRIVATE KEY BLOCK`.
**B5.5** — The audit and report signing keys (B10.4, B11.4) are synthetic, unprotected, carry the B5.2 comment, and live only in repository secrets. Jerry generates them once, offline, and loads them. They are never in git, never in `.heaven/`, and their comment makes them illegal in any ceremonied chain.
**B5.6** — Jerry's real root key never touches CI, `.heaven/`, `audit/`, `report/`, or either repo.

## B6. This file

**B6.1** — Describes payload, procedure, audit, grade. `SPEC.md` is normative for the module. Neither cites a chat round (P-12b).
**B6.2** — Every `B\d+\.\d+` here and `S\d+\.\d+` in SPEC is cited by a test via `# clause:` / `# spec:` (P-20).
**B6.3** — No commit shas, `file:line` refs, live counts, or numbered ranges. IDs are allowed. P-09.
**B6.4** — `## Frozen` and `## Amendments` below; Frozen hash change without an Amendments row in the same commit → P-08.

## B7. Plan tests

`tests/plan/playground/` runs only in the playground. `tests/plan/target/` ships in the payload and runs in both. No detection logic; the tree decides.

| ID | Where | Asserts |
|---|---|---|
| P-01 | playground | nothing under `src/`, `tests/` references `legacy/` |
| P-02 | playground | `Lift` green in empty temp dir |
| P-03 | both | S1.1 == `FunctionsToExport` == `Public/*.ps1` |
| P-04 | both | `Genesis.psm1` AST rule |
| P-05 | playground | no `BEGIN PGP` in listed paths |
| P-06 | both | no `git init` outside `.heaven/` |
| P-07 | playground | both lock files match |
| P-08 | playground | Frozen ⇒ Amendments |
| P-09 | playground | forbidden tokens absent |
| P-10 | playground | `.agents/*.md` per prefix |
| P-11 | playground | `.gitignore` has `.heaven/`,`.tools/`,`out/`; nothing under `src/`, `tests/`, `audit/` |
| P-12 | both | no short-circuit switches; P-12b no `round \d` |
| P-13 | both | lock pins per B2.1 |
| P-14 | playground, main | committed manifest == fresh `Payload` |
| P-15 | playground | PR body parser; P-15b no private key blocks |
| P-16 | playground | `ci.yml` runs `./build.ps1` bare |
| P-17 | both | default composition == tree |
| P-18 | playground | `src/` change ⇒ non-trivial test diff |
| P-19 | target | target history is refills only outside `report/` |
| P-20 | playground | every B and S clause cited |
| P-21 | target | `Receive` reports extra/missing/mismatch and writes nothing |
| P-22 | playground | `audit/` exists, is tracked, is not in `.gitignore`, is not in the payload |
| P-23 | playground | no `report/` anywhere in the playground or payload |

## B8. Agents and branches

**B8.1** — `main`: required check = `ci.yml` default; no force-push; no direct commits; CODEOWNERS `* @JerryBalmer1`. No `develop`.
**B8.2** — Prefixes `claude/*`, `grok/*`, `fable/*`, `opus/*`. CI fails a PR whose prefix ≠ `agent:` line.
**B8.3** — Review is CI on the SHA plus the audit chain. Pasted tails and chat are narration.
**B8.4** — Ownership: Claude — `SPEC.md`, `tests/chain/`; Grok — `tests/heaven/`; Opus — `src/`, `tests/unit/`; Fable — `tests/plan/` additions. Crossing requires a PR under the owner's prefix.
**B8.5** — v1 adversary is role separation in git history, not independent institutions. No stronger claim.
**B8.6** — Identity on a PR is the branch prefix, the `agent:` line, the required check on that SHA, and the audit receipt that names the review. Nothing else is claimed.

## B9. Open

1. **B10.4 custody.** The audit chain's root key must persist across CI runs to satisfy S4.4, so it lives in a repo secret. Anyone who can read repo secrets can forge an audit receipt. Named, not solved. The record is the bytes-in-git plus the parent walk (B10.8), not the signature — but say if a secret-held key is worse than no signature at all.
2. **B10.4 arming.** The chain cannot open before `New-GenesisRoot`, `New-GenesisReceipt`, `Test-GenesisChain` exist. Until then reviews are inbox files whose names are their hashes. Is a hash-named file in git an acceptable pre-chain record, or does every pre-arm PR have to be re-receipted after arming?
3. **B11.4 second custody.** `report/` is a Heaven too; same secret problem, second key.

## B10. Audit chain (the playground's own Heaven)

**B10.1** — `audit/` is a Heaven per S2 (`receipts/`, `content/`) plus `inbox/`. It is committed. It is not `.heaven/`, not `legacy/`, not the ceremony chain, and never in the payload (A4, P-22). Deleting, ignoring, or rewriting it is red.
**B10.2** — Receipts are S3 receipts, `receipt_type = receipt`. `kind = root` for a closure; `kind = operator-attributed` with `attributed_to ∈ {grok, claude}` for a review. No other value. No new enum member.
**B10.3** — One review, one receipt. `prompt_context` is `[<hash of the review file>]`; the review file is the raw UTF-8 (LF, no BOM) under `audit/content/`. `output_hash` is SHA-256 of the exact replacement text, or SHA-256("") for a rejection with no replacement. Two topics in one receipt is red. The receipt's review file lists every SPEC and GOD_PLAN ID touched, each marked `reject` or `accept`.
**B10.4** — Writers. Agents do not sign. An agent commits `audit/inbox/<sha256>` where the name is the SHA-256 of the bytes. The `Audit` CI job, holding the audit root key (B5.5), runs `New-GenesisReceipt -HeavenPath audit -ContextPath <inbox file> -OutputPath <replacement or empty> [-AttributedTo grok|claude]` for each inbox file in filename order, moves the bytes into `content/`, deletes the inbox entry, and commits as the bot. The chain is *armed* at the first commit where those three commands exist and pass their C tests; the job's first act is `New-GenesisRoot` on `audit/` with the audit key's public half and a second synthetic public half as successor. No history before that genesis.
**B10.5** — Pre-arm. Until B10.4 arms, every review and reply is still committed to `audit/inbox/` by hash name in the PR that answers it. On arming, the job receipts the inbox in name order; those receipts are the only record of pre-arm review. Chat is not a record before or after.
**B10.6** — `Audit` task, in default whenever `audit/` exists: `Test-GenesisChain -HeavenPath audit` is 0; every ID in the diff of `SPEC.md`, `GOD_PLAN.md`, `src/` since the tip's `source_commit` appears in some receipt's review file; no ID marked `accept` in a parent receipt is changed by its child; every reject receipt has a closure child or is listed open; the tip is not older than the newest `SPEC.md`/`GOD_PLAN.md`/`src/` commit; `inbox/` is empty at merge. Any line printed is a failed build. That printout is the judgment. There is no `-SkipAudit`.
**B10.7** — Append-only. Nobody edits `audit/content/` or `audit/receipts/`. A wrong receipt is followed by a correction receipt. Byte-level mismatch between Grok's file and what Claude appended is red.
**B10.8** — What is claimed: the bytes are in git, the filename is the hash, the parent walk reaches the audit genesis, CI verified the walk on the PR SHA. The synthetic signature exists because S3 requires one; it is not the record. No model identity is proved.
**B10.9** — Kaizen. A PR closes at most the IDs marked `reject` in its parent receipt, reopens no `accept`, adds nothing the parent did not demand. The closure review file names the IDs and files changed. Drive-bys are red under B10.6.
**B10.10** — No round-up documents. The chain is the round-up. This file does not restate reviews.

## B11. Grade (the product)

**B11.1** — `report/` exists in `ClaudeChain` only. `Receive` deletes any `report/` that arrives in a copy; the gut step in A2 preserves the target's own `report/`. Agents never create or touch it. P-23 keeps it out of the playground.
**B11.2** — Only the `ClaudeChain` CI job writes `report/**`, after `Receive` on a green default, committing as the bot with message prefix `report:`. Any other identity touching `report/**` is a trigger (B11.5) and red.
**B11.3** — `grade.ps1`, shipped in the payload, is the grader. It reads the trees and the audit chain (copied read-only into the run from the playground at `source_commit`) and writes `report/GRADE.md`. Wrong wording is a defect in `grade.ps1`: fix it in the playground, refill, regenerate. Old text stays in git.
**B11.4** — `report/` is a Heaven. Each generation appends `report/receipts/<hash>.json` (`receipt_type = receipt`, `kind = root`, `output_hash` = SHA-256 of that `GRADE.md`, previous bytes kept in `report/content/`). A generation not parented to the tip is `CHAIN_BREAK` and the job fails in public. Signed with the report key (B5.5).
**B11.5** — Triggers append a `discrepancy` to `report/receipts/` and print as the first lines of the next `GRADE.md`, exactly `TRIGGER <class> <receipt-hash>`, before any grade: non-bot commit on `report/**`; `GRADE.md` bytes changed without a receipt; missing parent; a playground push changing `SPEC.md`, `GOD_PLAN.md`, `src/`, or `audit/` with no new audit receipt; `Receive` finding any extra, missing, or mismatched file. Nothing auto-clears. A later `resolution` may follow; the trigger line stays in the report that recorded it.
**B11.6** — Sections, in order: **Verdict** (Grok, Claude, ClaudeChain, joint — each `pass` or `fail`, one sentence, evidence hash after); **Asked** (Jerry's expected result, copied from the audit content file that records it); **Grok** (open rejects; closures whose patch matches; accepts touched again; receipt hashes; no tone); **Claude** (Grok receipts with no child; paraphrases not hashing to Grok's file; spec/code PRs with no receipt; drive-bys); **Kaizen** (pass only if every closure PR names its parent and changes only those IDs); **ClaudeChain** (what was checked, what could not be, unresolved triggers; claiming coverage the tests lack is a fail); **Hashes** (tip of `audit/`, tip of `report/`, payload manifest hash, refill commit).
**B11.7** — `pass` requires the section's checks empty of failures. A check that could not run is `fail` and the ClaudeChain section says why. No letters, no scores.
**B11.8** — `GRADE.md` opens with instructions to the outside model: grade the four verdicts against the hashes, do not take them as true, report any trigger you can recompute. The packet is `GRADE.md` + `report/receipts/` + `report/content/`. No second summary.
**B11.9** — Jerry's expected result is recorded once, by Jerry, as an `audit/inbox/` file before the first `grade.ps1` runs; B11.6 **Asked** quotes it by hash. If it is absent, the Verdict section is four `fail` lines with reason `ASKED_ABSENT`.

## Frozen

(none)

## Amendments

| Clause | Reason | Proposed by |
|---|---|---|
| none | — | — |

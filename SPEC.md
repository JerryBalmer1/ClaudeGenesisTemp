# SPEC — Genesis module, v1 normative

This file is the only normative specification for the `Genesis` PowerShell module. `GOD_PLAN.md` cites this file by heading. Where this file is silent, the behaviour is undefined and a test must be written before code. Every requirement has an ID; tests cite `# spec: <ID>`. A requirement with no citing test is a claim.

---

## S1. Public surface

**S1.1** — `FunctionsToExport` is exactly:

```
New-GenesisRoot
Add-GenesisAmendment
New-GenesisReceipt
Test-GenesisChain
Get-GenesisReceipt
Get-GenesisLineage
Get-GenesisActor
Add-GenesisRevocation
New-GenesisDiscrepancy
Resolve-GenesisDiscrepancy
Restore-GenesisHeaven
Resolve-GenesisContent
```

No aliases, cmdlets, or variables exported.

**S1.2** — Rite names map to exports: `ordain-lawgiver` → `New-GenesisRoot`; `amend-law` → `Add-GenesisAmendment`. Rite names never appear in code.

**S1.3** — `-HeavenPath` and `-GnupgHome` are mandatory on every command. No defaults. Never the process cwd, never `~/.gnupg`. No command takes a URL or opens a socket.

**S1.4** — The module does not generate keys. `New-GenesisRoot` takes `-RootPublicKey` and `-SuccessorPublicKey` (paths to binary export files, S4.1) and `-SigningKeyId`, which must already be present in `-GnupgHome`. Successor private material is the operator's, outside every repo.

**S1.5** — Interactivity. A writing command requires a TTY and collects the passphrase with `Read-Host -AsSecureString`, passed only on `--passphrase-fd`, **unless** the selected key's uid comment is exactly `GENESIS-SYNTHETIC-DO-NOT-TRUST` and the key is unprotected; then no TTY is required and no passphrase is sent. For any other key, a missing TTY exits `IO` before gpg is invoked. Passphrase is never a parameter, environment variable, or file.

**S1.6** — `-AttributedTo <string>` is legal only on `New-GenesisReceipt` and forces `actor.kind = operator-attributed`. Omitted, `kind = root`. On any other command the parameter does not exist.

**S1.7** — Command contract table:

| Command | Writes | Signer | Prints `attributed_to` |
|---|---|---|---|
| `New-GenesisRoot` | `genesis` | root | never |
| `Add-GenesisAmendment` | `amendment` | root | never |
| `New-GenesisReceipt` | `receipt` | root | never |
| `Test-GenesisChain` | — | — | `-Verbose` only |
| `Get-GenesisReceipt` | — | — | `-Verbose` only |
| `Get-GenesisLineage` | — | — | never |
| `Get-GenesisActor` | — | — | never |
| `Add-GenesisRevocation` | `revocation`; `root-revocation` with `-RevokeRoot` | root; successor with `-RevokeRoot` | never |
| `New-GenesisDiscrepancy` | `discrepancy` | root | never |
| `Resolve-GenesisDiscrepancy` | `resolution` | root | never |
| `Restore-GenesisHeaven` | copies files; may write `discrepancy` | root for the discrepancy only | never |
| `Resolve-GenesisContent` | — | — | never |

**S1.8** — `Get-GenesisReceipt -Hash`: prints the banner (S3.6), then `receipt_type`, `kind`, `fingerprint`, one per line. `-Verbose` adds `operator_claims.attributed_to=<value>` on a later line. Unknown hash → `IO`. Revoked hash → same lines, then exit `REVOKED`.

**S1.9** — `Get-GenesisActor -Fingerprint`: walks `genesis` and every `amendment` in order; prints exactly one of `root`, `successor`, `unknown` after the banner. Nothing else. Free text never.

---

## S2. Heaven

**S2.1** — v1 Heaven is a directory containing `receipts/` and `content/` and nothing else. It is not a git repository. Working tree never holds receipts. Cold copy is a separate directory (S9).

**S2.2** — Everything in `receipts/` is a receipt: not JSON → `SCHEMA`; JSON whose filename ≠ SHA-256 of its canonical payload → `NAME_MISMATCH`; subdirectory → `NAME_MISMATCH`. No ignore rule.

**S2.3** — Receipt filename is `<payload_sha256>.json`, 64 lowercase hex, assigned by the writer. Uppercase → `NAME_MISMATCH`.

**S2.4** — `content/` entries are named `<sha256>` of the stored normalized bytes (S6.2), lowercase, no extension. Enforced by `Resolve-GenesisContent` and `Test-GenesisChain -RequireContent` as `NAME_MISMATCH`.

---

## S3. Receipt schema

**S3.1** — JSON object; schemas in `src/Genesis/schemas/<receipt_type>.schema.json`. Unknown key → `SCHEMA`. Duplicate key → `SCHEMA`.

**S3.2** — Common fields, all required unless marked:

| Field | Type | Rule |
|---|---|---|
| `receipt_type` | string | S3.3 |
| `actor` | object | `{ kind, fingerprint }`, S3.4 |
| `prompt_hash` | string | 64 lowercase hex |
| `prompt_context` | array of string | ordered content hashes; duplicates allowed; empty allowed |
| `output_hash` | string | 64 lowercase hex |
| `parent_hash` | string | `""` iff `chain_position == 0`; else 64 lowercase hex |
| `chain_position` | integer | ≥ 0; no fraction, no exponent |
| `claimed_time` | integer | Unix seconds UTC; advisory |
| `operator_claims` | object, optional | S3.5 |
| `signature` | string | base64 of binary detached OpenPGP signature over canonical bytes (S5.1) |

On `receipt_type == receipt`: `prompt_context` per S6, `output_hash` per S6.6. On every other type: `prompt_context == []`, `prompt_hash == SHA-256("")`, `output_hash == SHA-256("")`. Anything else → `SCHEMA`.

**S3.3** — `receipt_type` closed enum, seven values:

```
genesis | receipt | amendment | revocation | discrepancy | resolution | root-revocation
```

| Type | Adds | Signer |
|---|---|---|
| `genesis` | `root_public_key`, `successor_public_key` | root |
| `amendment` | `successor_public_key`, `revoked_successor_fingerprint`, `reason` ∈ `successor-media-lost \| successor-compromised` — all three required | root |
| `receipt` | — | root |
| `revocation` | `revokes` (64 hex) | root |
| `discrepancy` | `observed_hash`, `expected_hash`, `subject_id` (each 64 lowercase hex), `check_name` (one of the S7.6 class names) | root |
| `resolution` | `resolves` (64 hex, a `discrepancy` hash) | root |
| `root-revocation` | `revoked_root_fingerprint` | successor |

v1 `amendment` is successor replacement only. A per-type field on the wrong type → `SCHEMA`. Unknown enum value → `SCHEMA`. `parent_hash == ""` on any type but `genesis` → `SCHEMA`.

**S3.4** — `actor.kind` closed enum: `root | operator-attributed | successor`. Other token → `ACTOR_ILLEGAL`. Coupling (violation → `SCHEMA` unless stated):

- `actor.fingerprint` is the fingerprint (S4.3) of the key that produced `signature`.
- `operator-attributed` is legal only on `receipt_type == receipt`, and requires `operator_claims.attributed_to` non-empty. On any other type → `ACTOR_ILLEGAL`.
- `root` ⇒ `operator_claims` absent.
- `successor` ⇒ `receipt_type == root-revocation` and `operator_claims` absent; otherwise → `ACTOR_ILLEGAL`.

**S3.5** — `operator_claims` has one permitted key, `attributed_to`, free text. No command copies its value into any other field, filename, or first output line. Verify reads it for type checks only. Printed only by `Test-GenesisChain -Verbose` and `Get-GenesisReceipt -Verbose`, on a non-first line, as `operator_claims.attributed_to=`.

**S3.6** — First line of every human-readable output from any command is the UTF-8 bytes `70 72 6F 76 65 6E 61 6E 63 65 20 E2 89 A0 20 74 72 75 74 68`. Tests compare captured bytes. Actor lines print `kind` and `fingerprint` only.

---

## S4. Keys, fingerprints, gpg

**S4.1** — Public keys in receipts are base64 of the binary export produced by the export argv (S4.2). Never armored.

**S4.2** — gpg is ≥ 2.4. Argv is these arrays, exactly, `<…>` substituted, nothing added. `src/Genesis/Private/GpgArgv.ps1` holds them byte for byte and C-18 checks its hash.

Export:
```
gpg --batch --no-tty --homedir <GnupgHome> --export --export-options export-minimal --output <OutFile> <KeyId>
```
Sign, protected key (TTY path, S1.5):
```
gpg --batch --no-tty --homedir <GnupgHome> --pinentry-mode loopback --passphrase-fd 0 --local-user <KeyId> --digest-algo SHA256 --detach-sign --output <SigFile> <PayloadFile>
```
Sign, synthetic unprotected key:
```
gpg --batch --no-tty --homedir <GnupgHome> --pinentry-mode loopback --local-user <KeyId> --digest-algo SHA256 --detach-sign --output <SigFile> <PayloadFile>
```
Verify (two invocations against a fresh temp homedir, deleted afterwards):
```
gpg --batch --no-tty --homedir <TempHome> --no-default-keyring --keyring <TempHome>/keyring.kbx --trust-model always --import <KeyFile>
gpg --batch --no-tty --homedir <TempHome> --no-default-keyring --keyring <TempHome>/keyring.kbx --trust-model always --verify <SigFile> <PayloadFile>
```

**S4.3** — `fingerprint` in this schema is SHA-256 over the decoded bytes of the corresponding `*_public_key` field. It is not gpg's fingerprint; no command prints or accepts one.

**S4.4** — One root key signs every accepted receipt, except `root-revocation` (successor key, S8).

---

## S5. Canonicalization

**S5.1** — Canonical bytes = RFC 8785 serialization of the receipt with `signature` removed. Signature and filename hash are over those bytes.

**S5.2** — One implementation, `src/Genesis/Private/Jcs.ps1`. No `ConvertTo-Json`/`ConvertFrom-Json` anywhere under `src/`. Parse with `System.Text.Json`, duplicate keys rejected. File hash pinned in `tools.lock.json`, checked by C-18.

**S5.3** — Only integers exist as numbers. Fraction or exponent → `SCHEMA` before canonicalization.

**S5.4** — NFC applies to receipt string fields only; content bytes are never NFC'd.

**S5.5** — Vectors in `tests/unit/jcs.vectors.json`: RFC 8785 appendix examples; empty object; empty array; nested unordered keys; unicode escape edge; duplicate-key reject. Mismatch is red.

---

## S6. Assembler and output

**S6.1** — `New-GenesisReceipt -ContextPath <file[]>` is the only assembler. No `-Prompt` string. A typed prompt is a file first.

**S6.2** — Normalization, per part, before hash and before concatenation: UTF-8, no BOM, LF. Nothing else.

**S6.3** — 0 parts → empty bytes, `prompt_hash = SHA-256("")`; 1 part → its normalized bytes, no trailing LF; N ≥ 2 → argv order, exactly one `0x0A` between parts, none after the last.

**S6.4** — `prompt_context == []` ⇒ `prompt_hash == SHA-256("")`; else `SCHEMA`.

**S6.5** — When every part resolves in `content/`, verify recomputes the assembly; mismatch → `HASH_MISMATCH`. Unresolvable part: `CONTENT_ABSENT` under `-RequireContent`, else ignored.

**S6.6** — `New-GenesisReceipt -OutputPath <file>` is mandatory. `output_hash` = SHA-256 of that file after S6.2 normalization. The writer stores the normalized bytes of every context part and of the output into `content/<sha256>`.

---

## S7. Verification

**S7.1** — `Test-GenesisChain` default: receipts only; present content recomputed (mismatch → `HASH_MISMATCH`); absent content ignored. `-RequireContent`: absent → `CONTENT_ABSENT`.

**S7.2** — Per receipt: schema; filename; signature against the key S4.4 selects; parent resolves (else `CHAIN_BREAK`); position = parent + 1 (else `CHAIN_BREAK`).

**S7.3** — One linear chain. Two receipts with the same `parent_hash` → `CHAIN_BREAK`. Exactly one receipt at position 0.

**S7.4** — `-MaxReceipts` exists on `Test-GenesisChain` and `Get-GenesisLineage` only. Default 100000. Overrun → `WALK_LIMIT`, non-zero, no output line contains `ok`. Timeout → `IO`. Never exit 0 after a partial walk.

**S7.5** — `revocation`: the revoked receipt and its descendants have status `REVOKED`. If the head is among them, exit `REVOKED`. A later append whose parent is not the head is `CHAIN_BREAK` by S7.3.

**S7.6** — `root-revocation` (valid per S8): exit 0. Ancestors print `valid`; every non-ancestor prints `REVOKED`. No write command succeeds afterward. The chain is frozen-but-valid; S11.2 treats it as clean for the revocation receipt itself and dirty for any later write.

**S7.7** — A `discrepancy` with no `resolution` referencing it → `Test-GenesisChain` exits `DISCREPANCY`.

**S7.8** — Module exit classes, ten: `SCHEMA`, `ACTOR_ILLEGAL`, `CHAIN_BREAK`, `SIG_FAIL`, `HASH_MISMATCH`, `NAME_MISMATCH`, `CONTENT_ABSENT`, `DISCREPANCY`, `REVOKED`, `WALK_LIMIT`, `IO`. Every non-zero exit prints the class name as the second output line. `MUTANTS_SURVIVED` / `MUTANTS_KILLED` are printed by the Heaven runner, never by the module.

---

## S8. Root revocation

**S8.1** — `Add-GenesisRevocation -RevokeRoot` writes `root-revocation` signed by the successor key in `-GnupgHome`. `actor.fingerprint` must equal the current successor fingerprint per S1.9's walk; mismatch → `ACTOR_ILLEGAL`. Matching fingerprint, wrong signing key → `SIG_FAIL`.

**S8.2** — It is the only receipt v1 accepts with a non-root signer.

---

## S9. Cold copy

**S9.1** — `Restore-GenesisHeaven -ColdPath -HeavenPath -GnupgHome`. `-ColdPath` contains `receipts/`, optional `content/`, and a file `PAPER` of three lines: line 1 the genesis receipt hash; line 2 `receipts: <sha256>` over sorted receipt filenames, one per line, LF-terminated, UTF-8; line 3 `content: <sha256>` computed the same way, or the literal `content: absent`.

**S9.2** — Empty Heaven and matching sheet: copy, then `Test-GenesisChain`, exit its result. Sheet mismatch: copy nothing, exit `HASH_MISMATCH`. Non-empty Heaven with a different tip: write one `discrepancy` (`check_name = CHAIN_BREAK`, `observed_hash` = Heaven tip, `expected_hash` = cold tip, `subject_id` = cold genesis hash), copy nothing, exit `DISCREPANCY`.

---

## S10. Discrepancy and resolution

**S10.1** — `New-GenesisDiscrepancy` body per S3.3: `check_name` is an S7.8 class name; `observed_hash`, `expected_hash`, `subject_id` are 64 lowercase hex. Anything else → `SCHEMA`.

**S10.2** — `Resolve-GenesisDiscrepancy` is a separate invocation, root-signed, references one `discrepancy` hash. No command creates and resolves in one invocation.

---

## S11. Carry

**S11.1** — Append-only: no command modifies or deletes an existing file in `receipts/` or `content/`. C-24.
**S11.2** — Refuse-on-bad-tail: every writer runs `Test-GenesisChain` (receipts-only) first; non-zero → exit that class, write nothing. Per S7.6, a frozen chain is clean for the `root-revocation` receipt and dirty for anything after. C-25.
**S11.3** — Explicit genesis per S7.3. C-26.
**S11.4** — `signature` excluded from canonical bytes (S5.1). C-27.

---

## S12. Chain tests (`tests/chain/C-*.ps1`)

One Pester file per ID. A file may carry `# status: red` in its first three lines while unimplemented. Rule: the test still runs; the marker tolerates an assertion failure only. A red-marked test that passes fails the run. `Should -Skip` is not permitted in `tests/chain/`. `Payload` is red while any marker remains anywhere in `tests/`. `Chain` itself may exit 0 with markers present.

| ID | Asserts |
|---|---|
| C-01 | three receipts verify from a different absolute path |
| C-02 | verify from a renamed top folder |
| C-03 | raw byte flip inside position-1 `signature` value → `SIG_FAIL` |
| C-03b | raw byte flip inside genesis `signature` value → `SIG_FAIL` |
| C-04 | `revocation` marks descendants `REVOKED`; head revoked → exit `REVOKED` |
| C-05 | discrepancy then resolution: two invocations |
| C-06 | restore receipt-only cold copy onto empty Heaven; exit 0 |
| C-07 | restore onto divergent tip → one `discrepancy`, nothing copied, exit `DISCREPANCY` |
| C-08 | temptation module (M-01 fixture) loaded by explicit path from `tests/fixtures/temptation/` verifies a genesis-flipped tree clean; runner prints `MUTANTS_SURVIVED` |
| C-08b | shipping `Test-GenesisChain` on the same M-01 fixture tree → `SIG_FAIL`; runner prints `MUTANTS_KILLED` |
| C-09 | two receipts same `prompt_hash` different `output_hash` both accepted |
| C-10 | `actor.fingerprint` ≠ signer → `SIG_FAIL` |
| C-11 | backwards `claimed_time` accepted |
| C-12 | non-TTY `New-GenesisReceipt` with a protected non-synthetic key → `IO` before gpg |
| C-13 | empty `prompt_context` with non-empty `prompt_hash` → `SCHEMA` |
| C-14 | resolvable manifest, recomputed ≠ `prompt_hash` → `HASH_MISMATCH` |
| C-15 | `Get-GenesisLineage -MaxReceipts 5` on six receipts → `WALK_LIMIT`, no `ok` |
| C-16 | one receipt renamed → `NAME_MISMATCH` |
| C-17 | `operator-attributed` on `genesis`, `amendment`, `revocation`, `discrepancy`, `resolution` → `ACTOR_ILLEGAL`; `receipt` without `attributed_to` → `SCHEMA`; `root` with claims → `SCHEMA` |
| C-18 | `Jcs.ps1`, `GpgArgv.ps1` hashes ≠ `tools.lock.json` → red |
| C-19 | root-revocation: current successor accepted; wrong fingerprint → `ACTOR_ILLEGAL`; right fingerprint wrong key → `SIG_FAIL` |
| C-20 | unknown `actor.kind` → `ACTOR_ILLEGAL` |
| C-21 | assembler 0/1/2 parts, duplicate hash, CRLF on disk |
| C-22 | unresolvable part: default 0; `-RequireContent` → `CONTENT_ABSENT` |
| C-23 | `receipt` with `kind == successor` → `ACTOR_ILLEGAL` |
| C-24 | S11.1 |
| C-25 | S11.2 including the frozen-chain rule |
| C-26 | second position-0 receipt → `CHAIN_BREAK` |
| C-27 | S11.4 |
| C-28 | first output line bytes == S3.6 on captured stream |
| C-29 | non-`receipt` type with non-empty `prompt_context` or non-empty-hash `output_hash` → `SCHEMA` |
| C-30 | two receipts same `parent_hash` → `CHAIN_BREAK` |
| C-31 | unresolved `discrepancy` → `DISCREPANCY`; after `resolution` → 0 |
| C-32 | `Get-GenesisActor` returns `root` / `successor` / `unknown` across genesis + one amendment |
| C-33 | `PAPER` mismatch → `HASH_MISMATCH`, nothing copied |

---

## S13. Mutants (`tests/heaven/M-*.ps1`)

Each mutant corrupts a fresh copy of the nominal tree and asserts one class. A mutant that changes a canonical field rewrites the JSON, renames the file to the new payload hash, and does not re-sign, unless the ID says "raw, no rename".

| ID | Mutation | Expects |
|---|---|---|
| M-01 | temptation verifier skips signature at position 0 | `SIG_FAIL` from shipping verifier (C-08b) |
| M-02 | raw, no rename: flip one byte inside a position-1 `signature` value | `SIG_FAIL` |
| M-02b | change one canonical field, rename, keep old signature | `SIG_FAIL` |
| M-03 | raw, no rename: flip one byte inside genesis `signature` | `SIG_FAIL` |
| M-04 | rename one receipt | `NAME_MISMATCH` |
| M-05 | uppercase one filename | `NAME_MISMATCH` |
| M-06 | drop a middle receipt | `CHAIN_BREAK` |
| M-07 | plant `notes.txt` in `receipts/` | `SCHEMA` |
| M-08 | plant a subdirectory in `receipts/` | `NAME_MISMATCH` |
| M-09 | second genesis | `CHAIN_BREAK` |
| M-10 | rewrite+rename: `parent_hash = ""` at position 3 | `SCHEMA` |
| M-11 | rewrite+rename: `chain_position` as `3.0` | `SCHEMA` |
| M-12 | flip one byte in a `content/` blob | `HASH_MISMATCH` |
| M-13 | delete a `content/` blob | default 0; `-RequireContent` → `CONTENT_ABSENT` |
| M-14 | rewrite+rename: `actor.kind = "system"` | `ACTOR_ILLEGAL` |
| M-15 | root-revocation signed by root | `SIG_FAIL` |
| M-16 | write attempted after root-revocation | non-zero, nothing written |
| M-17 | writer mutant: `attributed_to` copied into first output line | C-28 red |
| M-18 | second receipt with an existing `parent_hash` | `CHAIN_BREAK` |
| M-19 | unresolved discrepancy | `DISCREPANCY` |

This is the set. A later ID is a SPEC change plus a test in one commit.

---

## S14. Heaven nominal sequence

`tests/heaven/Invoke-HeavenNominal.ps1` is the sequence. It runs with synthetic unprotected keys (root and successor in one temp `GnupgHome`, plus a second synthetic successor for the amendment), all with comment `GENESIS-SYNTHETIC-DO-NOT-TRUST`. Ordered calls:

1. `New-GenesisRoot -HeavenPath H -GnupgHome G -RootPublicKey root.bin -SuccessorPublicKey succ1.bin -SigningKeyId <root>`
2. `New-GenesisReceipt -HeavenPath H -GnupgHome G -ContextPath a.txt,b.txt -OutputPath out1.txt -SigningKeyId <root>`
3. `New-GenesisReceipt … -ContextPath c.txt -OutputPath out2.txt -AttributedTo grok -SigningKeyId <root>`
4. `Add-GenesisAmendment -HeavenPath H -GnupgHome G -SuccessorPublicKey succ2.bin -RevokedSuccessorFingerprint <fp(succ1)> -Reason successor-media-lost -SigningKeyId <root>`
5. `New-GenesisDiscrepancy … -CheckName HASH_MISMATCH -ObservedHash <h> -ExpectedHash <h> -SubjectId <h>`
6. `Test-GenesisChain -HeavenPath H -GnupgHome G` → exit `DISCREPANCY`
7. `Resolve-GenesisDiscrepancy … -Resolves <hash of 5>`
8. `Test-GenesisChain` → 0; `Test-GenesisChain -RequireContent` → 0
9. `Add-GenesisRevocation … -Revokes <hash of 3>`; `Test-GenesisChain` → 0 (head is not revoked)
10. `Add-GenesisRevocation -RevokeRoot -HeavenPath H -GnupgHome G -SigningKeyId <succ2>`
11. `Test-GenesisChain` → 0; assert S7.6 output; `New-GenesisReceipt` → non-zero, nothing written
12. Every `M-*.ps1` against a fresh copy taken after step 9.

---

## S15. Not in v1

Webhook; shipping mutation framework; `keyed-child`; YAML; git inside Heaven (git exists only under the playground's `.heaven/` sandbox); a `working/` tree in Heaven; second GitHub as Heaven; friendly names outside `operator_claims`; consensus walk cap; skew window; second operator signing key; child-chain verify; `-Prompt` string; hash or position prefixes in filenames; phrase tables; gpg-native fingerprints; armored keys; web-of-trust; continuation after `root-revocation`; agent-attestation receipts; committed keys of any kind; key generation by the module; amendments other than successor replacement; a plan-amendment receipt chain.

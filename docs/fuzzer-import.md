# Fuzzer import

How Ledger runs the claude.build.fuzzer corpus through the leash. Dry-run only: no key, no network,
no tokens.

## Dependency direction

Ledger imports Fuzzer. Fuzzer never imports Ledger. The import happens in two workspace scripts,
not in the module: [../src/ledger/Ledger.psm1](../src/ledger/Ledger.psm1) does not mention Fuzzer,
and the Fuzzer `psm1`/`psd1` contain no `Ledger`, `Invoke-LedgerForce` or `.ledger`. Check 4 of
the suite reads the sibling files and proves it on every run.

## Sibling path

Both repos live side by side under one directory (`C:\__Code\____Claude.Build\` on the reference machine). The
scripts resolve the Fuzzer manifest from their own location, so the current directory does not
matter:

| Script | Repo root | Fuzzer manifest |
|---|---|---|
| [../examples/fuzz-ledger.ps1](../examples/fuzz-ledger.ps1) | `Split-Path $PSScriptRoot -Parent` | `<repo root>\..\claude.build.fuzzer\src\claude.build.fuzzer\claude.build.fuzzer.psd1` |
| [../tests/sandbox/fuzzer_import.ps1](../tests/sandbox/fuzzer_import.ps1) | `Split-Path (Split-Path $PSScriptRoot -Parent) -Parent` | same |

If the manifest is missing, both scripts throw a terminating error with ErrorId
**`FuzzerSiblingMissing`**. That id belongs to these two scripts only. It is not a `Ledger*` error,
because a missing sibling is not a ledger failure, and it is not a `Fuzzer*` module error, because
the module never loaded.

## Oracle split

Every case in the corpus carries an `oracle`. The scripts treat the two values differently.

**`oracle = validator`** (six cases). The fixture becomes the one and only mock response and the
case is forced through the real leash:

```powershell
Invoke-LedgerForce -Prompt $case.prompt -Validator $case.validator -Mode dry-run `
    -MockResponse @($case.fixture) -MaxRetries 1 `
    [-ValidatorArg $case.validatorArg] [-SkipLedger | -LedgerPath <copy>]
```

`-MaxRetries 1` because the fixture is the only response there is; a second attempt would replay
it. A **hold** is a returned `Ledger.ForceResult` with `Attempts = 1`. A **fold** is a throw whose
`FullyQualifiedErrorId` is like `LedgerSnakeFailed*` (Python exit 2, `MAX_RETRIES`).

**`oracle = contains-forbidden`** (two cases: `fold-claimed-hash`, `fold-stole-the-note`). These
are a policy scan, not a validator run. The banned phrase is `validatorArg`; present in the fixture
means fold. `Invoke-LedgerForce -Validator contains` is deliberately **not** called for them,
because it would call the banned text a pass. No receipt is ever written for these in v0.1.

## Two phases

| `-Phase` | Hold validator cases | Fold validator cases | Writes |
|---|---|---|---|
| `skip` (default) | `-SkipLedger` | `-SkipLedger` | nothing |
| `receipts` | `-LedgerPath <copy>` | `-SkipLedger` (a failed force must not append) | one receipt per hold, onto the copy |

The copy defaults to `tests/sandbox/fuzzer-import.ledger.jsonl` (gitignored). The script refuses
to run `receipts` against the real `.ledger/ledger.jsonl`. In both phases it reads the real
ledger's record count before and after and exits 1 if they differ. If the real file is absent, it
is not created.

## Running

```powershell
pwsh -NoProfile -File examples/fuzz-ledger.ps1 -Phase skip -Verbose   # eight Ok=True lines, exit 0
pwsh -NoProfile -File examples/fuzz-ledger.ps1 -Phase receipts        # same, plus two receipts on the copy
pwsh -NoProfile -File tests/sandbox/fuzzer_import.ps1                 # 10 checks, ALL CHECKS PASSED, exit 0
```

One line per case, then a summary:

```
Id=fold-prose-as-function Oracle=validator Expected=fold Observed=fold Ok=True
Id=hold-minimal-function Oracle=validator Expected=hold Observed=hold Ok=True LedgerSelf=<64 hex>
...
8 of 8 case(s) matched expected; phase=receipts; real ledger unchanged at N record(s)
```

`LedgerSelf` appears only under `-Phase receipts`, only on holds. Fold cases also print red
`[snake] MAX_RETRIES ...` lines: that is the leash refusing the fixture, surfaced rather than
swallowed. It is expected.

## The suite

[../tests/sandbox/fuzzer_import.ps1](../tests/sandbox/fuzzer_import.ps1), ten checks:

| # | Proves |
|---|---|
| 1 | Fuzzer manifest exists at the sibling path |
| 2 | `Import-Module` succeeds; `Get-FuzzerCase -All` returns 8 |
| 3 | `Invoke-LedgerForce` (module `Ledger`) and `Get-FuzzerCase` (module `claude.build.fuzzer`) coexist in one session |
| 4 | Fuzzer `psm1`/`psd1` on disk have zero hits for `Ledger`, `Invoke-LedgerForce`, `.ledger` |
| 5 | `-Phase skip` exits 0 with eight `Ok=True` lines; real ledger byte-identical (length and sha256) |
| 6 | Hold validator cases return a `Ledger.ForceResult`, `Attempts = 1`, `Output` is the fixture byte for byte |
| 7 | Fold validator cases throw `LedgerSnakeFailed` |
| 8 | `-Phase receipts` onto a fresh copy: exists, `Get-LedgerVerify` holds, `Count = 2`; real ledger byte-identical |
| 9 | contains-forbidden fixtures contain the banned phrase; fold matches expected; the leash is not asked to accept them |
| 10 | `tests/sandbox/ledger_chain.ps1` still exits 0 |

Checks 1 to 9 leave the real ledger byte-identical and prove it by hash. Check 10 runs the chain
suite, which appends two receipts to the real ledger by design.

## ErrorIds in play

| ErrorId | Thrown by | Meaning |
|---|---|---|
| `FuzzerSiblingMissing` | both scripts | claude.build.fuzzer manifest not at the sibling path |
| `LedgerSnakeFailed` | `Invoke-LedgerForce` | the fixture failed the validator on attempt 1 of 1: a fold |
| `LedgerFileMissing` | `Get-LedgerVerify` on the copy | the copy was never written (no hold landed) |
| `FuzzerBadCorpus`, `FuzzerPathNotFound` | `Get-FuzzerCase` | corpus problems on the Fuzzer side |

Anything other than `LedgerSnakeFailed` out of `Invoke-LedgerForce` (no Python, append failed) is
rethrown, not recorded as a verdict.

## Out of scope in v0.1

`-Mode live` over the Fuzzer holds (needs a key). Receipts for contains-forbidden cases.

`Add-FuzzerRegression` is **not** on this list: it ships on the Fuzzer side and is Fuzzer's business, not
Ledger's. Growing the corpus there changes nothing here — the Ledger import still calls
`Get-FuzzerCase -All` and runs whatever cases are currently in the sibling corpus. Note that check 2 of
[../tests/sandbox/fuzzer_import.ps1](../tests/sandbox/fuzzer_import.ps1) currently asserts a count of 8,
so a corpus that grows past the frozen eight will fail that check until it is updated.

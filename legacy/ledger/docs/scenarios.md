# Scenarios — do X when Y

Every command here is copy-pasteable and runs with **no API key**, except the one explicitly
marked live. Run `.ps1` files with `pwsh -NoProfile -File` from the repo root.

| When you want to... | Do this |
|---|---|
| [Run a safe demo with no key](#1-run-a-safe-demo-with-no-key) | `pwsh -NoProfile -File examples/force_example.ps1 -Verbose` |
| [See reject then feedback then retry](#2-see-reject--feedback--retry) | Same, with `-Verbose`; add `-Debug` for the raw exchange |
| [Prove the chain](#3-prove-the-chain) | `Import-Module`, then `Get-LedgerVerify` |
| [Read the last N receipts](#4-read-the-last-n-receipts) | `Get-LedgerEntry -Last N` |
| [Force without writing a receipt](#5-force-without-writing-a-receipt) | `Invoke-LedgerForce -SkipLedger` |
| [Write receipts somewhere else](#6-write-receipts-somewhere-else) | `-LedgerPath <path>` |
| [Live call with no key](#7-live-call-with-no-api-key) | Expect `LedgerMissingApiKey`, count unchanged |
| [Validator never passes](#8-validator-never-passes) | `pwsh -NoProfile -File tests/sandbox/fail_path.ps1 -Verbose` |
| [Someone edited a hex digit](#9-someone-edited-a-hex-digit) | Copy the ledger, flip a digit, verify the copy |
| [Confirm dry-run purity](#10-confirm-dry-run-purity) | Assert `anthropic` is absent from `sys.modules` |

---

## 1. Run a safe demo with no key

```powershell
pwsh -NoProfile -File examples/force_example.ps1 -Verbose
```

**Expected shape.** Verbose narration of the retry loop, then three blocks:

```
=== ACCEPTED OUTPUT ===
def add(a, b):
    return a + b
=== LEDGER ENTRY ===
Validator : has_function_def
Reason    : found 'def ' and 'return'
Attempts  : 2
Sha256    : ba1a531f581d2e60...
Model     : claude-sonnet-4-5
Mode      : dry-run
=== RECEIPT (appended) ===
LedgerPath : ...\.ledger\ledger.jsonl
LedgerSelf : <64 hex>
```

Exit code `0`. Exactly one line is appended to `.ledger/ledger.jsonl`.

**On failure.** `LedgerPythonMissing` if `python` is not on `PATH`; `LedgerCliMissing` if
`src/ledger/python/cli.py` is absent.

## 2. See reject then feedback then retry

```powershell
pwsh -NoProfile -File examples/force_example.ps1 -Verbose
```

**Expected shape.** The first attempt is rejected, the second passes:

```
VERBOSE: [snake] --- attempt 1/5 ---
VERBOSE: [snake] attempt 1: INVALID - no 'def ' and 'return' token in output; it is prose, not a function
VERBOSE: [snake] attempt 1/5 rejected: ...
VERBOSE: [snake] --- attempt 2/5 ---
VERBOSE: [snake] attempt 2: VALID - found 'def ' and 'return'
VERBOSE: [snake] accepted on attempt 2/5 (sha256 ba1a531f581d...)
```

For the raw request/response internals, including the feedback message fed back to the model, use
`-Debug`. The example sets `$DebugPreference = 'Continue'` when `-Debug` is passed, so it will not
prompt:

```powershell
pwsh -NoProfile -File examples/force_example.ps1 -Debug
```

## 3. Prove the chain

```powershell
Import-Module ./src/ledger/Ledger.psd1 -Force
Get-LedgerVerify -Verbose | Format-List
```

**Expected shape.**

```
Path     : C:\__Code\____Claude.Build\claude.build.ledger\.ledger\ledger.jsonl
Count    : 2
Ok       : True
FirstTs  : 2026-09-19T02:15:01.160Z
LastTs   : 2026-09-19T02:15:02.251Z
LastSelf : 4da4584de8b5237e...
```

A returned object *is* the proof — any break throws instead of returning `Ok = $false`.

**On failure.** `LedgerFileMissing` (no file yet — run the example first), `LedgerCorruptLine`,
`LedgerBadRecord`, `LedgerBadSelf`, `LedgerBrokenChain`.

## 4. Read the last N receipts

```powershell
Get-LedgerEntry -Last 5 | Format-Table Line, Ts, Attempt, Mode, Sha256
```

**Expected shape.** Oldest first, at most 5 rows:

```
Line Ts                       Attempt Mode    Sha256
---- --                       ------- ----    ------
   1 2026-09-19T02:15:01.160Z       2 dry-run ba1a531f581d2e60...
   2 2026-09-19T02:15:02.251Z       2 dry-run ba1a531f581d2e60...
```

`-Last 0` returns every record. An empty file emits nothing.

To check the link between the two most recent records yourself:

```powershell
$p = @(Get-LedgerEntry -Last 2)
$p[1].Prev -eq $p[0].Self        # True
```

**On failure.** `LedgerFileMissing`, or the per-record ErrorIds above.

## 5. Force without writing a receipt

```powershell
Import-Module ./src/ledger/Ledger.psd1 -Force
$r = Invoke-LedgerForce -Prompt 'Write add(a, b).' -Validator has_function_def -Mode dry-run -SkipLedger
$r.LedgerPath   # $null
$r.LedgerSelf   # $null
```

**Expected shape.** A normal `Ledger.ForceResult` with `LedgerPath` and `LedgerSelf` both `$null`,
and `Get-LedgerVerify` reporting an unchanged `Count`. Verbose prints
`[ledger] -SkipLedger: output accepted, no receipt written`.

Use it for throwaway experiments. An output you actually rely on should leave a receipt.

## 6. Write receipts somewhere else

```powershell
Invoke-LedgerForce -Prompt 'Write add(a, b).' -Mode dry-run `
    -LedgerPath ./tests/sandbox/scratch.jsonl -Verbose

Get-LedgerVerify -LedgerPath ./tests/sandbox/scratch.jsonl
```

**Expected shape.** The parent directory is created if absent. The new file starts its own chain,
so its first record has `prev` = 64 zeros. `Count` is 1 on the first run.

Relative paths resolve against **your current directory**, not the module's. Absolute paths are
used as given. Anything under `tests/sandbox/` is gitignored except `.ps1` files.

**On failure.** `LedgerAppendFailed` if the path is unwritable — note the force itself already
succeeded, and the accepted result is on the ErrorRecord's `TargetObject`.

## 7. Live call with no API key

```powershell
Import-Module ./src/ledger/Ledger.psd1 -Force
$before = (Get-LedgerVerify).Count
try {
    Invoke-LedgerForce -Prompt 'Write add(a, b).' -Mode live -Verbose
} catch {
    $_.FullyQualifiedErrorId          # LedgerMissingApiKey,Invoke-LedgerForce
    $_.CategoryInfo.Category          # AuthenticationError
}
(Get-LedgerVerify).Count -eq $before  # True
```

**Expected shape.** A terminating error before Python is ever spawned:

```
ANTHROPIC_API_KEY is not set. Set it or use -Mode dry-run. No key will be invented.
```

**Expected ErrorId:** `LedgerMissingApiKey`. No receipt is written and `Count` is unchanged. This
scenario costs nothing and is safe to run anywhere.

## 8. Validator never passes

```powershell
pwsh -NoProfile -File tests/sandbox/fail_path.ps1 -Verbose
```

[../tests/sandbox/fail_path.ps1](../tests/sandbox/fail_path.ps1) feeds a mock that can never
satisfy `has_function_def`, so the snake exhausts its cap and exits `2`.

**Expected shape.**

```
=== TERMINATING ERROR CAUGHT (expected) ===
FullyQualifiedErrorId : LedgerSnakeFailed,Invoke-LedgerForce
Category              : OperationStopped
InnerException        : NativeCommandExitException
Message               : Snake failed with exit code 2: MAX_RETRIES: validator never satisfied after 3 attempts...
PASS: non-zero Python exit surfaced as a terminating PowerShell error.
```

Script exit code `0` — it passes by *catching* the error. **Expected ErrorId:**
`LedgerSnakeFailed`. No receipt is written: the failure terminates before the append.

The point of this scenario is that a Python non-zero exit is never a silently-set `$LASTEXITCODE`.
That is `$PSNativeCommandUseErrorActionPreference = $true` doing its job.

## 9. Someone edited a hex digit

Never test this against the real ledger — work on a copy.

```powershell
Import-Module ./src/ledger/Ledger.psd1 -Force

$src = '.ledger/ledger.jsonl'
$dst = 'tests/sandbox/broken.jsonl'
$lines = @([System.IO.File]::ReadAllLines($src, [System.Text.UTF8Encoding]::new($false)))

# Flip one hex digit of the last record's sha256. Nothing else changes.
$null = $lines[-1] -match '"sha256":"([0-9a-f]{64})"'
$orig = $Matches[1]
$flip = $(if ($orig[0] -eq '0') { 'f' } else { '0' }) + $orig.Substring(1)
$lines[-1] = $lines[-1] -replace "`"sha256`":`"$orig`"", "`"sha256`":`"$flip`""
[System.IO.File]::WriteAllText($dst, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))

try { Get-LedgerVerify -LedgerPath $dst } catch { $_.FullyQualifiedErrorId; $_.Exception.Message }
```

**Expected shape.**

```
LedgerBadSelf,Get-LedgerVerify
line 2: record was tampered with. self says 4da4584de8b5..., payload hashes to f392cebe4f5f...
```

**Expected ErrorId:** `LedgerBadSelf` — the record no longer hashes to its own `self`. You would
see `LedgerBrokenChain` instead if a record were deleted, inserted or reordered while each record
stayed internally consistent.

To make the tamper undetectable you would have to recompute `self` for the edited record *and*
`prev` and `self` for every record after it.

## 10. Confirm dry-run purity

The dry-run path must never import the `anthropic` SDK. Assert it rather than trusting it:

```powershell
pwsh -NoProfile -File tests/sandbox/ledger_chain.ps1
```

Test 4 of the suite generates a checker into `tests/sandbox/` (gitignored, written at run time),
runs a full dry-run through `cli.main()` with a patched stdin, and inspects `sys.modules`.

**Expected shape.**

```
py| CHECK exit_code=0 anthropic_modules=none
py| OK: dry-run completed with anthropic absent from sys.modules
PASS  dry-run ran to completion with anthropic absent from sys.modules
```

**On failure.** The checker exits non-zero, which — under
`$PSNativeCommandUseErrorActionPreference = $true` — terminates and fails the suite. A leak means
something made the SDK import eager; the import must stay inside `Snake._live_transport()`.

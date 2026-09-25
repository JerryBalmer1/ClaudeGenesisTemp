# Verification

How Ledger v0.1 was proven, and what a reviewer can re-run. **Every command on this page runs
without an API key and spends no tokens.**

## The suite

[../tests/sandbox/ledger_chain.ps1](../tests/sandbox/ledger_chain.ps1) — **96 checks, all passing**.

```powershell
pwsh -NoProfile -File tests/sandbox/ledger_chain.ps1
```

Exit code `0` and a final `ALL CHECKS PASSED`; exit `1` and a failure count otherwise.

| # | Test | Checks | Asserts |
|---|---|---|---|
| 1 | Example appends one receipt | 3 | `Ok` is true; `Count >= 1`; exactly one line appended |
| 2 | Second run links | 4 | `Count` incremented by 1; two records returned; line N `prev` == line N-1 `self`; `LastSelf` matches the final record |
| 3 | Tampered copy throws | 3 | Verify threw; ErrorId is `LedgerBadSelf`; the real ledger is untouched |
| 4 | Dry-run purity | 1 | `cli.main()` completes with `anthropic` absent from `sys.modules` |
| 5 | Live mode, no key | 3 | Threw; ErrorId is `LedgerMissingApiKey`; no receipt written |
| — | `-SkipLedger` | 3 | `LedgerPath` null; `LedgerSelf` null; `Count` unchanged |
| 8 | Output rehash | 15 | A hash that does not match its output throws `LedgerOutputHashMismatch` and appends nothing, under the default path and `-SkipLedger` alike; uppercase hex of an otherwise honest digest fails the same way |
| 10 | Result matches the invocation | 13 | A `mode`, `validator` or named `model` echoed back different from the invocation throws `LedgerResultMismatch`; the compare is case-sensitive; an omitted `-Model` records the parameter default, not the snake's echo; an omitted field is silent, not wrong |

Test 3 works on a **copy** in `tests/sandbox/`; the real ledger is never modified, and check 3.3
proves it. Test 4 generates its Python checker at run time into `tests/sandbox/` (gitignored), so
nothing generated is committed.

Checks assert the specific ErrorId, not merely that *something* threw — a test that passes for the
wrong reason is not a test.

## The second suite

[../tests/sandbox/fuzzer_import.ps1](../tests/sandbox/fuzzer_import.ps1) — **10 checks, 53
assertions, all passing**. It imports the sibling `claude.build.fuzzer` repo and runs its eight frozen
cases through `Invoke-LedgerForce` in dry-run, proves the real ledger stays byte-identical, then
re-runs `ledger_chain.ps1` as its final check. Details in [fuzzer-import.md](fuzzer-import.md).

```powershell
pwsh -NoProfile -File tests/sandbox/fuzzer_import.ps1
```

## What a full run shows

Dry-run, attempt 1 rejected, attempt 2 accepted:

```
VERBOSE: [snake] --- attempt 1/5 ---
VERBOSE: [snake] attempt 1: INVALID - no 'def ' and 'return' token in output; it is prose, not a function
VERBOSE: [snake] --- attempt 2/5 ---
VERBOSE: [snake] attempt 2: VALID - found 'def ' and 'return'
VERBOSE: [snake] accepted on attempt 2/5 (sha256 ba1a531f581d...)
VERBOSE: [ledger] receipt #2: prev=f5c58b49190b... self=4da4584de8b5...
```

The accepted output hashes to
`ba1a531f581d2e6094e978ed6f7aca7a8d92eeb62c6e7ad73ee692f7f18bc772` on attempt 2, and
`Get-LedgerVerify` returns `Ok = $true`.

Both runs produce the **same** `sha256` (identical accepted text) but **different** `self`, because
`ts` and `prev` differ. That is the chain distinguishing two separate events with identical
content — the intended behaviour, asserted by check 2.3.

## Re-runnable checks

### 1. The whole suite

```powershell
pwsh -NoProfile -File tests/sandbox/ledger_chain.ps1
```

### 2. The example, end to end

```powershell
pwsh -NoProfile -File examples/force_example.ps1 -Verbose
```

Appends exactly one receipt; ends with `=== RECEIPT (appended) ===` and a `LedgerSelf` hash.

### 3. The chain holds

```powershell
Import-Module ./src/ledger/Ledger.psd1 -Force
Get-LedgerVerify -Verbose | Format-List
```

`Ok : True` with a `Count` matching the number of runs.

### 4. Failure surfaces as a terminating error

```powershell
pwsh -NoProfile -File tests/sandbox/fail_path.ps1 -Verbose
```

Python exits `2`; PowerShell raises `LedgerSnakeFailed`. The script exits `0` because it passes by
catching that error.

### 5. Encoding is what it claims

```bash
file .ledger/ledger.jsonl                      # New Line Delimited JSON text data
tr -cd '\r' < .ledger/ledger.jsonl | wc -c     # 0  -> LF only, no CRLF
head -c 3 .ledger/ledger.jsonl | od -c         # starts with {  "  t  -> no BOM
```

### 6. The canonical form is language-independent

The strongest check available without a key: re-derive the chain in Python and confirm it agrees
with the hand-rolled PowerShell emitter, byte for byte.

```bash
python - <<'PY'
import hashlib, json, pathlib
KEYS = ["ts","attempt","validator","mode","model","sha256","prev"]
prev = "0"*64
for i, line in enumerate(pathlib.Path(".ledger/ledger.jsonl").read_text(encoding="utf-8").splitlines(), 1):
    if not line.strip():
        continue
    r = json.loads(line)
    canon = json.dumps({k: r[k] for k in KEYS}, separators=(",", ":"), ensure_ascii=False)
    got = hashlib.sha256(canon.encode("utf-8")).hexdigest()
    assert got == r["self"], f"line {i}: self mismatch"
    assert r["prev"] == prev, f"line {i}: broken link"
    prev = r["self"]
    print(f"line {i}: self OK  prev OK  {got[:16]}...")
print("Python agrees with PowerShell on every canonical hash.")
PY
```

Expected:

```
line 1: self OK  prev OK  f5c58b49190be3be...
line 2: self OK  prev OK  4da4584de8b5237e...
Python agrees with PowerShell on every canonical hash.
```

This is a genuinely independent implementation — `json.dumps` with compact separators over the
seven payload keys reproduces the hand-written PowerShell output exactly. If it ever disagrees,
the canonical form has drifted and the chain is no longer portable.

Note this snippet uses `json.loads` purely to *read back* values that are then re-serialized in a
fixed key order; it does not rely on the parser preserving formatting. The PowerShell verifier
deliberately avoids `ConvertFrom-Json` for the reason given in [do-not.md](do-not.md).

## Two bugs found and fixed during implementation

Recorded because both are easy to reintroduce.

**`ConvertFrom-Json` destroyed the chain.** It parsed the ISO-8601 `ts` into a `[datetime]`;
re-stringifying could not reproduce the hashed bytes, so every record failed verification on the
first run. Fixed by parsing with `System.Text.Json`. Both halves of the hash path — writer and
reader — are now serializer-free.

**Native stderr merged into the pipeline turned verbose output into a throw.** Under
`$ErrorActionPreference = 'Stop'`, piping a native command's `2>&1` can surface ordinary chatter as
error records. The suite therefore runs the example with no redirection and checks `$LASTEXITCODE`,
and sends the Python checker's stderr to a file. Both places carry an inline comment so the
workaround is not "tidied" away later.

## Environment this was run on

| | |
|---|---|
| PowerShell | 7.6.6 |
| Python | 3.10.4 |
| Platform | Windows 11 |
| Mode | `dry-run` throughout — no live API calls, no `pip install` |

The module requires PowerShell **7.4+** (`#Requires -Version 7.4`, manifest
`PowerShellVersion = '7.4'`); 7.6.6 is simply what was on the machine.

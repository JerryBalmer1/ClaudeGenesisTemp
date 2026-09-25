# Ledger

The snake that makes Claude obey. A PowerShell 7.4+ module wrapping a Python validate-retry loop,
with an append-only, SHA-256 hash-chained receipt for every accepted output.

## What it does
- Wraps Claude API calls in `Invoke-LedgerForce`.
- Validates every response against a named validator: `contains`, `has_function_def`, `is_json`, `matches`, `non_empty`.
- On failure, feeds the specific rejection reason back to the model and retries, up to `-MaxRetries` (default 5, max 20). After the cap it halts and throws `LedgerSnakeFailed`. No begging, no infinite loop.
- On success, PowerShell appends one receipt to `.ledger/ledger.jsonl`, chained by SHA-256 to the one before it. `Get-LedgerVerify` proves nothing was edited, inserted or dropped.
- Dry-run is the default: a scripted mock transport, no key, no network, no tokens.

## Structure
- `src/ledger/Ledger.psd1`, `src/ledger/Ledger.psm1` - the module: the leash, the ledger writer, the verifier
- `src/ledger/python/cli.py` - subprocess entry point; NDJSON events on stdout
- `src/ledger/python/snake.py` - `Snake.force()`, the validate-retry loop
- `src/ledger/python/validators.py` - the five named validators
- `examples/force_example.ps1` - dry-run: reject, feedback, retry, accept, one receipt
- `examples/fuzz-ledger.ps1` - the claude.build.fuzzer corpus through the leash (see below)
- `tests/sandbox/ledger_chain.ps1`, `tests/sandbox/fuzzer_import.ps1` - the two suites
- `docs/` - theory of operation, command reference, scenarios, footguns, verification
- `requirements.txt` - the `anthropic` SDK, needed only for `-Mode live`

## PowerShell
```powershell
Import-Module ./src/ledger/Ledger.psd1 -Force

$r = Invoke-LedgerForce -Verbose `
    -Prompt 'Write a Python function add(a, b) that returns a + b. Code only.' `
    -Validator has_function_def `
    -MaxRetries 5 `
    -Mode dry-run

$r.Output
$r | Format-List Attempts, Sha256, LedgerSelf
Get-LedgerVerify | Format-List
```

`-Validator <name>` picks one of the five validators; `contains` and `matches` take `-ValidatorArg`.
There is no `-ValidatorScript`. Live mode is `-Mode live` with `ANTHROPIC_API_KEY` set.
Full reference: `docs/commands.md`.

## Python
The Python is the compute engine. The module drives it over stdin/stdout and it never writes the
ledger. There is no `ledger.snake` package to import; `snake.py` lives in `src/ledger/python/` and
is loaded by `cli.py`.

```powershell
pip install -r requirements.txt            # only for -Mode live
python src/ledger/python/cli.py --help
python examples/force_example.py           # live; needs ANTHROPIC_API_KEY; writes no receipt
```

## claude.build.fuzzer is a sibling, not a dependency
`claude.build.fuzzer` (adversarial cases that make the model fold) is a separate repo checked out next to
this one. `examples/fuzz-ledger.ps1` imports it by sibling path and runs its eight frozen cases
through `Invoke-LedgerForce` in dry-run; `tests/sandbox/fuzzer_import.ps1` proves it in ten checks.
`Ledger.psm1` never imports Fuzzer, Fuzzer never imports Ledger, and if the sibling is missing the
scripts throw `FuzzerSiblingMissing`. See `docs/fuzzer-import.md`.

## Run it
```powershell
pwsh -NoProfile -File examples/force_example.ps1 -Verbose
pwsh -NoProfile -File tests/sandbox/ledger_chain.ps1
pwsh -NoProfile -File tests/sandbox/fuzzer_import.ps1
```

Requires PowerShell 7.4+ and Python 3.10+. Run `.ps1` files with `pwsh -NoProfile -File`, never
under Git Bash. Docs index: `docs/README.md`.

Claude doesn't get a choice. Neither do you. Ship it.

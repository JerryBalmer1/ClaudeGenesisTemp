---
name: build-snake
description: Implement or improve the Ledger snake — Python retry loop plus PowerShell 7.4 native error capture, verified with -Verbose.
---

# Build the Snake

## When to use
When the user asks to implement or improve the snake, or when starting a new session on this project.

## Steps
1. Read `src/ledger/python/snake.py` and `validators.py`.
2. Check the PowerShell module in `src/ledger/Ledger.psm1`.
3. Ensure `$PSNativeCommandUseErrorActionPreference = $true` is set.
4. Implement or fix the snake.
5. Add verbose/debug output.
6. Create a test that runs with `-Verbose` and shows everything.
7. Run the test, verify output, push to remote.

## Checklist
- [ ] PowerShell 7.4+ required in manifest
- [ ] Native command errors captured
- [ ] Verbose output visible
- [ ] Debug output visible
- [ ] Test passes with -Verbose
- [ ] Pushed to remote

## Implementation plan
1. Create `src/ledger/python/snake.py` with a `Snake` class.
2. Implement `force(prompt, validator)` that:
   - Calls Claude API (or a mock for testing).
   - Validates the response.
   - If invalid, feeds the error back and retries (up to N times).
   - Returns the valid response or raises after max retries.
3. Create `validators.py` with validation functions.
4. Wire it into the PowerShell module so `Invoke-LedgerSnake` (or similar) calls the Python snake.
5. Add verbose/debug output in PowerShell that shows the Python process, its output, and any errors.
6. Create a test in `tests/` or `examples/` that demonstrates the full flow with `-Verbose`.
7. Create a nested sandbox directory (e.g. `tests/sandbox/`) for git init testing.
8. Test, verify, then push to remote.

## Success criteria
- Running the PowerShell function with `-Verbose` shows the Python snake working, retries happening, and errors being captured.
- The module requires PowerShell 7.4+.
- Git sandbox works: Claude can init, commit, push.

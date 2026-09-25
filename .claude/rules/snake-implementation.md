# Snake Implementation Plan

## Goal
Build a Python class `Snake` in `src/ledger/python/snake.py` that forces Claude compliance through retries.

## Steps for Claude (the AI)
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

## Success Criteria
- Running the PowerShell function with `-Verbose` shows the Python snake working, retries happening, and errors being captured.
- The module requires PowerShell 7.4+.
- Git sandbox works: Claude can init, commit, push.

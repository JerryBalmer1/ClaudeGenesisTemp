---
name: test-verbose
description: Run the Ledger example with -Verbose -Debug and confirm Python errors surface as PowerShell errors.
---

# Test with Verbose and Debug

## When to use
When verifying the PowerShell module works and shows output.

## Steps
1. Run `pwsh -File examples/force_example.ps1 -Verbose -Debug`
2. Confirm Python output, errors, and retries are visible.
3. Confirm non-zero Python exits become PowerShell errors.
4. If anything is silent, fix it.

## Verification requirements
- Verbose and debug output must be visible on screen when running tests or examples.
- Use a nested sandbox dir (e.g. `tests/sandbox/` or `examples/sandbox/`) for isolated git testing: init, create files, commit, push to a remote.
- After building the snake, test it, verify it works, then push the result to the remote so it can be checked.

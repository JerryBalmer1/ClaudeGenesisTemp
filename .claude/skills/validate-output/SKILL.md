---
name: validate-output
description: Run the full validator suite against a candidate output and return structured results.
---

# Validate output

- Check schema (required fields present).
- Check constraints (rules from .claude/rules/).
- Check ledger integrity (hash chain unbroken).
- Return { pass: bool, violations: [...] }.

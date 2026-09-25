---
paths: ["**/*.py"]
---

# Python conventions for Ledger
#
# - Target Python 3.10+ (this box runs 3.10.4; keep syntax 3.10-compatible).
# - Type hints on all public functions.
# - Use logging, not print(), for anything the PowerShell wrapper needs to surface.
# - Structured JSON lines on stdout for events the PS module parses.
# - No bare except. Catch specific exceptions, log, re-raise or return a typed error.
# - Keep snake.py pure: no side effects outside the retry loop.
#
# Docs: https://docs.python.org/3/tutorial/classes.html

"""Example: force Claude to write a working function, straight from Python.

This is the live path and needs ANTHROPIC_API_KEY. For the dry-run that burns
no tokens, go through the PowerShell wrapper instead:

    pwsh -NoProfile -File examples/force_example.ps1 -Verbose

Exit codes match the snake CLI: 0 accepted, 2 retry cap exhausted, 4 no key.
"""
from __future__ import annotations

import json
import os
import sys

# The snake modules live at src/ledger/python, which is not on sys.path by
# default -- the package directory is 'python', not 'ledger'.
_SNAKE_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "ledger", "python")
)
sys.path.insert(0, _SNAKE_DIR)

from snake import Snake, SnakeError  # noqa: E402
from validators import has_function_def  # noqa: E402


def main() -> int:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print(
            "ANTHROPIC_API_KEY is not set. Set it, or use the dry-run path:\n"
            "  pwsh -NoProfile -File examples/force_example.ps1 -Verbose",
            file=sys.stderr,
        )
        return 4

    snake = Snake(
        model="claude-sonnet-4-5",
        max_retries=5,
        on_event=lambda event: print(json.dumps(event), file=sys.stderr),
    )

    try:
        result = snake.force(
            prompt="Write a Python function add(a, b) that returns a + b. Only the code.",
            validator=has_function_def(),
            system="You are a code generator. Output only code, no explanation.",
        )
    except SnakeError as exc:
        print("snake failed: {0}".format(exc), file=sys.stderr)
        return 2

    print(result.output)
    print(
        "# accepted on attempt {0}, sha256 {1}".format(result.attempts, result.sha256),
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

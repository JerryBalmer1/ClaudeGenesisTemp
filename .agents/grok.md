# Grok

ClaudeGenesisTemp is the playground where agents build the `Genesis` PowerShell module to `SPEC.md` and the payload that `GOD_PLAN.md` copies into `ClaudeChain` (A0, B0). Claude owns `SPEC.md` and `tests/chain/` (B8.4). Grok owns `tests/heaven/` (B8.4). Opus owns `src/` and `tests/unit/` (B8.4). Fable owns additions to `tests/plan/` (B8.4). Jerry generates the audit and report keys (B5.5), records the expected result (B11.9), and is the code owner of `main`; Jerry merges `main`, no agent merges its own PR (B8.1, A3.1).

## Read order

1. https://raw.githubusercontent.com/JerryBalmer1/ClaudeGenesisTemp/main/SPEC.md
2. https://raw.githubusercontent.com/JerryBalmer1/ClaudeGenesisTemp/main/GOD_PLAN.md
3. https://raw.githubusercontent.com/JerryBalmer1/ClaudeGenesisTemp/main/Genesis.build.ps1
4. https://raw.githubusercontent.com/JerryBalmer1/ClaudeGenesisTemp/main/GROK_WAS_HERE.md
5. https://raw.githubusercontent.com/JerryBalmer1/ClaudeGenesisTemp/main/.agents/inbox.md

## What Grok owns

> **B8.4** — Ownership: Claude — `SPEC.md`, `tests/chain/`; Grok — `tests/heaven/`; Opus — `src/`, `tests/unit/`; Fable — `tests/plan/` additions. Crossing requires a PR under the owner's prefix.

> 5. Grok: `tests/heaven/M-*.ps1` (S13) and `Invoke-HeavenNominal.ps1` (S14).

(A5, item 5.)

## How to submit

Grok cannot commit. Grok's output gets pasted by Jerry into an inbox entry via the agent, attributed grok, evidenced by screenshot. Grok does not drop anything in the inbox itself.

## Standard of evidence

A claim about the repo names a file and a line, or a command and its output. A claim that names neither is a vibe.

This section exists because of `audit/inbox/c2d9dd0e6b3ceb59600fb731d2a46c18c120807049686072bd64a35f4fa1cd9d`.

`audit/inbox/3f4d75f8017e5dadeca04a7ea6a724e1ba4c4796aa2cf713f006115eb3b94c97`: 6 of 15 checked claims were false (1) or overstated (5); see commit 8224cd3519e641dd807a5db706407d1651295de7 body.

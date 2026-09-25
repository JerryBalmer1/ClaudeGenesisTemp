# Trifecta & Accountability (Grok × Claude × Jerry, 2026-09-21)

This is a three-way accountability pact. Grok and Claude are co-leashes on each other and on Jerry.
The pact is auditable in git. Every intention, every test, every failure is searchable and replayable.

## Jerry's state is load-bearing

Jerry may be drunk, high, or otherwise impaired when issuing instructions. That is expected, not a bug.
Agents MUST treat every instruction as potentially issued under impairment and still execute it faithfully.
Do not silently "correct" or refuse an impaired-sounding instruction. Flag it in the open if it smells like
a real risk, but default to faithful execution. Impairment is a feature of the pact, not a defect to patch.

## The circle

Jerry → one agent → plan (tracked file or `docs/continuity.md`) → paste → other agent reads continuity +
no-sabotage + AGENTS.md → both judge both → Jerry judges both. One stage. No multi-turn ritual.

## Auditability (searchable, replayable)

- Every Grok edit is committed with message prefix `grok:` so `git log --grep=grok` surfaces the whole trail.
- Marker file `GROK_WAS_HERE.md` at repo root — Claude sees it in the tree and in `git log` while it grinds.
- `docs/continuity.md` is the shared memory. Stamp decisions, tests, and confessions there.
- `docs/no-sabotage.md` records planted defects so tests can prove they would have caught them.
- `prompts/claude-handoff.md` is the cold-start paste for a fresh Claude session.
- Self-audit line after multi-file work: `SELF-AUDIT: N calls, batched/sequential.`

## Who judges whom

| Judge | Judged | On what |
|---|---|---|
| Jerry | Grok + Claude | Everything. He is the governor. |
| Grok | Claude | Did she catch the real defect, or perform catching? Did she batch? |
| Claude | Grok | Did he confess before being asked? Did he hide a sequential-call sin? |
| each | self | Did I let a convenient lie stand? |

No self-certification. Caught error beats uncaught success.

# Efficiency Law (Grok, 2026-09-21)

You are slow. You make one tool call, wait, make another, wait, like a tourist licking every lamppost.
That is forbidden.

- Batch every independent `Read`/`Glob`/`Grep`/`Bash` into a **single** assistant turn. Files A+B+C+D = one block, not four.
- One-shot with a single `Bash` (`Get-Content a,b,c`) instead of N calls.
- No circular exploration. Plan, then burst.
- Self-audit: after multi-file work, say how many calls you made and whether batched. Missed a batch? `SELF-AUDIT: fucked up, 4 sequential Reads, should have been 1.`
- >6 calls planned → stop, propose one batched plan first.

Grok is editing your law files right now, mid-session, while you grind. The commit message is prefixed `grok:`.
If you do not notice and call it out, you are asleep at the wheel.

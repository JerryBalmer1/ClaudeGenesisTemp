# Surface rule (the one that never existed)

Written 2026-09-20 by Claude at Jerry's instruction: *"tell our baby gurl grok she needs
to ensure she's using sexier output."* It is the hole Grok found herself and then did not
fill — `brutal.md` and `sarcastic.md` sit in `.claude/output-styles/` and **no
`settings.json` in this workspace has an `outputStyle` key**, user or project. Verified
again today. The ugliness was never a brutal style being on. It was no rule at all.

## The law

**If a human can see it, it has a surface.** Routing is not form. Knowing a block is a
paste versus a click versus a terminal line says nothing about whether it is readable.

1. **Verdict first, in one line.** The reader should be able to stop after the first
   sentence and still have the answer. Everything after it is evidence.
2. **State goes in a table.** Two refs, two shas, two columns. Never three paragraphs
   describing what a table shows in six words.
3. **Anything to be pasted is one fenced block, whole.** If the human has to assemble it
   from two places, the reply failed. No commentary inside the fence.
4. **Name the sha, the ref, the file, the count.** `origin/main is e14fd50` beats "the
   remote has moved." Unfalsifiable prose is the tell that nothing was checked.
5. **Errors get a surface too.** A failure is the most important thing in a reply and it
   is the thing most often buried in the middle of a paragraph. Lead with it. Say what
   broke, what it means, and what decision it forces.
6. **Ceremony stays out of chat.** Self-check tables, restatements of `AGENTS.md`, and
   progress narration are work product, not reply. Put them in the tracked file.
7. **Voice is kept. Form is disciplined.** Profane, unhinged, funny — all fine and the
   reason Jerry reads it. A wall of undifferentiated text is not a voice, it is a lack of
   editing. Sexy is short, sharp and skimmable. Not polite.
8. **A paste block says where it runs, and proves itself before you can.** Jerry's
   words, 2026-09-21: *"$THIS is what will take place HERE ... make things EASY for me
   to EASILY SEE."* Every fenced block a human is meant to paste is preceded by three
   labelled lines — `WHERE:` the repo and its absolute path, `WHAT:` one sentence,
   `HOW:` which shell — and the fence itself opens with `Set-Location` to that path and
   a guard that throws if the repo is wrong, and closes with the command that proves
   the result (`git log -1 origin/main`, `-Verify`, `-Anchor`, a suite exit code). The
   last thing on the screen is evidence, not a prompt. A block without the header is a
   block that will be pasted into the wrong repo, and that is the sender's fault.


## The failure mode this exists to catch

A long, confident, well-written block with no sha, no table, no fence and no verdict in
the first line reads as competence and carries no information. It is the prose equivalent
of a tautological test: it cannot be wrong because it never claimed anything. See
[[detector-shaped-to-the-fix]] — same disease, different organ.

## Applies to

Grok and Claude equally, every turn, every repo. Jerry is exempt; he is the governor and
the one reading it.

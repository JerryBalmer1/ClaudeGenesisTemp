# Snake rules
#
# 1. The model never writes freehand. Every output passes through a validator.
# 2. On validation failure, feed the failure back into the conversation and retry.
# 3. Cap retries (default 5). After the cap, halt and report — do not loop forever.
# 4. Never swallow errors. Surface them as terminating errors to PowerShell.
# 5. Hash every accepted output and append to the ledger.
#
# Docs: see CLAUDE.md and .claude/skills/build-snake/SKILL.md

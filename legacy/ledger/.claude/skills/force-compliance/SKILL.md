---
name: force-compliance
description: Force model output through the validator until it passes or hits the retry cap.
---

# Force compliance

1. Take the task and the current constraint set.
2. Generate output via the model.
3. Run validators. On failure, inject the violation list and retry.
4. Stop at retry cap (default 5) and report the final failure.
5. On pass, hash the output and append to the ledger.

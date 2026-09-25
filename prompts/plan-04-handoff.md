# Plan 04 handoff — accountability as code

> Written by Claude, 2026-09-21, from a session rooted at `claude.build.ledger`.
> Plan 04 targets `claude.pwsh.image.builder`, which is a different repo under
> different law ([[image-builder-is-not-this-workspace]]). Jerry ruled that the work
> happens there, in a session rooted there, so this file exists only to carry the
> cold-start findings across the boundary without a human retyping them.
>
> Everything in the block below was verified read-only on 2026-09-21 with `gh api`,
> `git`, `Get-Command` and `Test-Path`. Nothing in it is remembered. The next session
> should contradict it from the live tree and say so if it has moved — that is the
> failure this workspace has already paid for twice ([[fetch-before-contradicting]]).

Paste this as the first message in a brand-new Claude chat opened on
`claude.pwsh.image.builder`.

```
You are Claude, executing Plan 04 — accountability as code — in claude.pwsh.image.builder
(C:\__Code\____Claude.Build\claude.pwsh.image.builder). Jerry governs.

This repo's AGENTS.md, .ALLAGENTS.md, FLOW.md and AFTER-CLAUDE-COMMITS.md are your law.
claude.build.ledger's CLAUDE.md is NOT your law here, even if a sibling repo is open.

A prior session ran Plan 04 §0 from claude.build.ledger on 2026-09-21 and stopped at three
blockers. Do not re-derive the following. Do contradict it from the live tree, and say so.

VERIFIED 2026-09-21, read-only:
  terraform 1.9.8              OK (plan requires >= 1.9)
  gh 2.14.2 (2022-07-14)       STALE — ships from before the rulesets API existed.
                               `gh api` still reaches the endpoints; upgrade before -Task Verify.
  git 2.41.0  pwsh 7.6.6       OK
  gh auth                      JerryBalmer1, oauth_token
  token scopes                 gist, read:org, repo, user, workflow
                               `repo` covers Administration: write. The token is NOT the blocker.
                               (Plan 04 §0 predicted a read-only PAT. Wrong failure mode.)
  six repos                    all private; all default_branch=main
  develop                      EXISTS in claude.pwsh.image.builder ONLY, at 16e98fe
                               (= origin/develop, currently checked out, tree clean).
                               ledger/inspector/policy/fuzzer/orchestrator are main-only.
                               So §2.2's ref_name.include of refs/heads/develop must be
                               per-repo, driven by the tfvars protected_branches list —
                               a flat include list is wrong for five of the six.
  local main                   8f7446d, BEHIND origin/main 7cb86c5. Fetch before touching it.
  signing, today               gpg.format=ssh and user.signingkey are set
                               (ssh-ed25519 ... jerry.infra@gmail.com (signing)), but
                               commit.gpgsign UNSET, tag.gpgsign UNSET,
                               gpg.ssh.allowedSignersFile UNSET, ~/.ssh/claude.build ABSENT.
                               Nothing anywhere is signed. `git verify-commit HEAD` fails on
                               every repo right now. §4's verify step starts red, not partial.
  .build.ps1                   ABSENT.  main.tf ABSENT.  TFModule/ ABSENT.
  scripts/state.ps1            present (not run by the ledger session — out of its working set)
  docs/plans/backlog/          EMPTY. "Backlog 01" has no file. It was never written down.

THE BLOCKER THAT STOPPED THE FIRST RUN:
  gh api repos/JerryBalmer1/<any of the six>/rulesets                  -> HTTP 403
  gh api repos/JerryBalmer1/<any of the six>/branches/main/protection  -> HTTP 403
  "Upgrade to GitHub Pro or make this repository public to enable this feature."

  Identical on all six. Private repos on GitHub Free have no rulesets and no branch
  protection. Every rule in Plan 04 §2.2 rulesets.tf — required_signatures, pull_request,
  require_code_owner_review, required_status_checks, non_fast_forward, deletion — would
  403 on apply. Plan 04's thesis is prevention. On Free + private you can only buy
  detection.

JERRY'S RULING, 2026-09-21. This binds you:
  1. GitHub Pro. Repos stay private. Plan 04 ships as written once Pro is live.
  2. The work happens in this repo, under this repo's law.

ORDER. Do not skip a step:
  1. Jerry upgrades the account to GitHub Pro. Until then `terraform apply` cannot succeed
     and writing rulesets.tf is writing something you cannot test.
  2. Prove Pro is live with the probe below. Do not trust a billing page.
  3. .build.ps1 must exist. Plan 04 §2.3 adds tasks to a dispatcher that is not there, and
     backlog 01 is not written down anywhere. Either write and execute 01 first, or fold a
     minimum dispatcher into Plan 04 and say so explicitly in the plan's Context — do not
     let it appear by implication.
  4. Then Plan 04, plan-first: docs/plans/2026-09-21-accountability-iac.md from
     docs/plans/_template.md, copied to ACTIVE.md, branch feature/accountability-iac off
     develop at 16e98fe.

PROVE PRO IS LIVE (run before writing one line of rulesets.tf):
  foreach ($r in 'claude.build.ledger','claude.build.inspector','claude.build.policy',
                 'claude.build.fuzzer','claude.build.orchestrator','claude.pwsh.image.builder') {
    $rs = gh api "repos/JerryBalmer1/$r/rulesets" 2>&1 | Select-Object -First 1
    $ok = if ($rs -match '403|Upgrade') { 'STILL FREE' } else { 'PRO OK' }
    '{0,-30} {1}' -f $r, $ok
  }
  Six PRO OK lines, or stop and tell Jerry.

OPEN QUESTIONS — Plan 04's five, plus two the cold start added:
  - terraform backend: local+gitignored, or remote with locking. Jerry answers.
  - squash / rebase / merge-commit settings: read them, ignore_changes them, change nothing
    silently. If the plan wants squash off, that is an amendment, not a default.
  - mirror owner: which account or org, or null to skip §2.2 mirror.tf entirely.
  - signing-key upload: does integrations/github ~> 6.0 expose a resource for
    /user/ssh_signing_keys? Check the provider docs for the version `terraform init`
    actually resolves — do not answer from memory. If absent, gh api fallback, recorded in
    COMPLIANCE.md as the one GitHub-side thing Terraform does not own.
  - per-repo law_paths for inspector, policy, fuzzer, orchestrator: read each AGENTS.md.
    A guess is an open question, not a default.
  - NEW: does Pro enable require_code_owner_review on private repos, or only base
    protection? Verify against the live API after the upgrade. The ledger session did not
    verify this and did not assume it.
  - NEW: gh 2.14.2 is three years stale and -Task Verify leans on it. Upgrade, or pin the
    Verify task to raw `gh api` calls only.

DO NOT:
  No token or private key in the tree, in a plan, in evidence, or in a commit body.
  No `terraform apply` without -Go from Jerry; the agent never passes -Go.
  No destroy in an accepted plan. No bypass actors on any ruleset. No local-exec.
  No PowerShell calling the GitHub API for something the provider has a resource for.
  No editing a sibling's .git/config except through the As task.
  No pretending four keys on one GitHub account are four GitHub identities — say that
  sentence in COMPLIANCE.md, because an auditor will ask.

THE ORDER PROBLEM, which Plan 04 names and you must repeat in your report:
  the PR that adds the rulesets is itself merged before the rulesets exist. It is the last
  merge that is allowed to be unsigned. Every PR after `Apply -Go` must be signed or it
  cannot land. So `As -Actor` joins every agent's cold start from that point on — add the
  line to .ALLAGENTS.md.

FIRST ACTIONS:
  Read AGENTS.md, .ALLAGENTS.md, FLOW.md, AFTER-CLAUDE-COMMITS.md, docs/plans/ACTIVE.md.
  Run: pwsh -NoProfile -File scripts/state.ps1
  Then reply with exactly one line and nothing else:
      synced at <sha> on develop, standing by
  Then the state table and any contradiction with the block above. Then wait for go.
```

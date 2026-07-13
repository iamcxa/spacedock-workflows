---
title: Align C14 with First Officer stage-entry transitions
status: draft
source: blocker discovered while starting issue #20
started:
completed:
verdict:
score:
worktree:
issue: "#30"
pr:
---

The First Officer owns stage entry and currently records it with `dispatch: <feature> entering <stage>`, while C14 recognizes only the completion-side `advance-stage.sh` commit signature. The mismatch makes a legitimate FO `draft -> shape` transition fail the invariant and shell-suite baseline before feature work starts.

## Acceptance criteria

**AC-1 — Legitimate FO stage entry is mechanically recognized.**
Verified by: a RED-first fixture covering `draft -> shape` through the canonical FO dispatch path passes after the fix.

**AC-2 — Manual status bypass remains blocked.**
Verified by: arbitrary or lookalike commit messages that hand-edit frontmatter status without a sanctioned transition receipt continue to fail C14.

**AC-3 — Entry and completion contracts are aligned.**
Verified by: the workflow/FO-facing process contract names the stage-entry receipt, C14 recognizes it narrowly, and completion-side `advance-stage.sh` enforcement remains intact.

**AC-4 — Dogfood baseline is restored without allowlists.**
Verified by: the current branch passes invariants, the shell suite, and Node tests without commit-hash grandfathering or a forged `advance-stage.sh` signature.

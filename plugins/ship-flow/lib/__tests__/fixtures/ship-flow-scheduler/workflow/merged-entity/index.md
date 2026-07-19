---
title: Merged fixture entity (reconcile target)
status: execute
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict: PASSED
score:
worktree:
issue: 508
pr: 131
---

Fixture entity: a merged PR is on record (`pr: 131`, matching the EXISTING
`fixtures/merged-pr-closeout-reconciler/pr-merged.env` fixture's `number=131`).
No local `worktree:` recorded, so the reconciler's cleanup preflight is
`not_applicable` — hermetic, no real git-worktree state required.

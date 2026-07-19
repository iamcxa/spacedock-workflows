---
title: Prompt-captain fixture entity (reconcile target)
status: execute
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict: PASSED
score:
worktree:
issue: 509
pr: 131
---

Fixture entity: `pr: 131` but the linked PR fixture reports CLOSED (not merged),
matching the EXISTING `fixtures/merged-pr-closeout-reconciler/pr-closed.env`
fixture. The reconciler emits `PROMPT_CAPTAIN`; the tick must surface a terminal
`blocked` event, not a crash or a retry.

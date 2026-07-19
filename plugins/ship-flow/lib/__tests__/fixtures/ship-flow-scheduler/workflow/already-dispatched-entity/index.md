---
title: Already-dispatched fixture entity (replay-idempotence target)
status: shape
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict:
score:
worktree: .worktrees/already-dispatched-entity
issue: 507
pr: 89
---

Fixture entity models a crash that occurred AFTER worktree + PR creation. Both dedup
keys are already tripped. Running `tick` against a workflow dir containing only this
entity must never emit a `dispatch` event, on the first invocation OR any replay.

## Acceptance criteria

**AC-1 — Fixture works.** Verified by: this file existing and being read by the tick.

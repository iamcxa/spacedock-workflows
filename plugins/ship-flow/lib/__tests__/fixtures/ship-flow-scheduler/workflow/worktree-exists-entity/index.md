---
title: Worktree-exists fixture entity
status: shape
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict:
score:
worktree: .worktrees/worktree-exists-entity
issue: 505
pr:
---

Fixture entity: otherwise eligible, but a worktree is already recorded — dedup key
`worktree-exists` must exclude it from dispatch (no double-ship).

## Acceptance criteria

**AC-1 — Fixture works.** Verified by: this file existing and being read by the tick.

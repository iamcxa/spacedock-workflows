---
title: PR-exists fixture entity
status: shape
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict:
score:
worktree:
issue: 506
pr: 88
---

Fixture entity: otherwise eligible, but a PR is already recorded — dedup key `pr-exists`
must exclude it from dispatch (no double-ship).

## Acceptance criteria

**AC-1 — Fixture works.** Verified by: this file existing and being read by the tick.

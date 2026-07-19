---
title: Advance-epic parent fixture entity (reconcile target)
status: execute
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict: PASSED
score:
worktree:
issue: 510
pr: 131
id: "900.1"
parent_pitch: "900"
---

Fixture entity: a merged PR is on record (`pr: 131`, matching the EXISTING
`pr-merged.env` fixture). Belongs to epic `900`; reconciling it should surface
its sibling as newly ready via `dag-waves.sh --ready --epic 900`.

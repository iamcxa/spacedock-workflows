---
title: PR-live-only fixture entity (F1 crash-window regression)
status: shape
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict:
score:
worktree:
issue: 513
pr:
---

Fixture entity: shaped, issue OPEN + `sd:approved`, otherwise eligible — frontmatter
`worktree:`/`pr:` are BOTH empty, modeling a crash after the real `/ship` run opened
a PR but BEFORE it got far enough to write the `pr:` field. The tick must exclude
this entity via a LIVE gh lookup keyed by the entity's own conventional branch, not
the (empty, unwritten) frontmatter field.

## Acceptance criteria

**AC-1 — Fixture works.** Verified by: this file existing and being read by the tick.

---
title: CLOSED-PR-live-only fixture entity (W2 dedup case-arm regression)
status: shape
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict:
score:
worktree:
issue: 515
pr:
---

Fixture entity: shaped, issue OPEN + `sd:approved`, otherwise eligible — frontmatter
`worktree:`/`pr:` are BOTH empty, and the LIVE gh lookup for this entity's conventional
branch returns a CLOSED (not merged, not open) PR. The tick must still exclude this
entity from dispatch: a closed-unmerged PR on the branch is dedup ground truth (a
prior run already dispatched), not a green light for a fresh dispatch.

## Acceptance criteria

**AC-1 — Fixture works.** Verified by: this file existing and being read by the tick.

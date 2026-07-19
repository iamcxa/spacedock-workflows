---
title: Time-budget fixture entity
status: shape
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict:
score:
worktree:
issue: 502
pr:
time_budget: 2h30m
---

Fixture entity: shaped, issue OPEN + `sd:approved`, no worktree, no PR, and a
declared `time_budget: 2h30m`. Eligible for dispatch; AC-3a's
`derive_timeout_sec` must read this frontmatter field and derive 9000s.

## Acceptance criteria

**AC-1 — Fixture works.** Verified by: this file existing and being read by the tick.

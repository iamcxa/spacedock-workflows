---
title: Unknown-gh-state fixture entity (F4 transient-flake regression)
status: execute
source: fixture
started: 2026-07-01T00:00:00Z
completed:
verdict:
score:
worktree:
issue: 514
pr: 777
---

Fixture entity: `pr:` is recorded, but no matching `gh/pr-unknown-pr-state-entity.env`
fixture file exists, so the fixture gh-provider reports `UNKNOWN` (a stand-in for a
real transient `gh pr view` failure — auth/network/rate-limit). The tick must treat
this as a transient warning no-op, never a `reconciler-prompt-captain` escalation,
and must not mutate this entity's frontmatter.

## Acceptance criteria

**AC-1 — Fixture works.** Verified by: this file existing and being read by the tick.

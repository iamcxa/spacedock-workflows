---
id: "006-plan-attempt-vertical"
title: "Plan attempt vertical"
pattern: shaped-child
parent_pitch: "006"
depends-on: []
affects_ui: false
harvest_required: true
time_budget: 4h
layout: folder
worktree: .worktrees/spacedock-ensign-006-plan-attempt-vertical
started: 2026-07-23T00:13:19Z
status: plan
stage_outputs:
  shape: shape.md
  design: design.md
---

### Vertical Slice

Make one real plan caller consume the bounded attempt seam from fresh dispatch through one authoritative terminal contribution.

## Acceptance criteria

- **AC-1 — A real plan caller completes one fresh bounded attempt end to end.**
  Verified by: a focused integration test observes one plan worker dispatch, one authoritative return, and one terminal contribution under the fresh attempt budget.
- **AC-2 — Fresh-attempt authority is typed and caller-owned, not inferred from prose.**
  Verified by: the plan call path carries the attempt identity, start/budget authority, lease/ref bindings, and terminal outcome through the generic seam.
- **AC-3 — Validation starts with changed plan/attempt surfaces and cannot widen this child for unrelated full-suite failures.**
  Verified by: the child receipt names focused changed-surface checks first and records unrelated failures as deferred evidence without adding their owning paths.

## Stage Report: design

- DONE: Register the already-validated Phase 0 trivial-pass design through completion-v1 at the repaired eligible child HEAD.
  Completion registration published the canonical `design.md` stage output at `230531e5` after the bounded frontmatter repair restored exact eligibility.
- DONE: Keep the one-plan-caller boundary explicit; preserve `548b338` protocol/clock evidence without pulling recovery, execute, scheduler, dispatcher, `#21`, or sibling scope.
  The durable receipt repair changed only this child index; implementation, tests, product code, lease state, and sibling entities remain outside this report update.

### Summary

The already-validated Phase 0 trivial-pass design completed successful completion reconciliation at `230531e5`. The hand-off remains bounded to one real plan caller and preserves the `548b338` protocol/clock evidence without widening into recovery, execute, scheduler, dispatcher, `#21`, or sibling scope.

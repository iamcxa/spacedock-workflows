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
status: design
stage_outputs:
    shape: shape.md
worktree: .worktrees/spacedock-ensign-006-plan-attempt-vertical
started: 2026-07-23T00:13:19Z
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

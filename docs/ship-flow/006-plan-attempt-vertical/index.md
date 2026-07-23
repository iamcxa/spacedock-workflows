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
status: design
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

- DONE: Emit the ship-design Phase 0 trivial-pass artifact and hand-off without inventing new contract decisions.
  `design.md` records `status: trivial-pass`, unconditional `PROCEED`, and the canonical single-field `design-skipped: true` hand-off.
- FAILED: Register design completion through the canonical completion helper and preserve the first-child-only scope.
  Completion registration was not attempted because `SHIP_FLOW_COMPLETION_LEASE_FILE`, `SHIP_FLOW_COMPLETION_LEASE_TOKEN`, and `SHIP_FLOW_COMPLETION_WORKER_ID` are absent; no lease was fabricated.
- DONE: Report focused validation and a durable commit; do not touch implementation, tests, PRs, or sibling entities.
  Focused design-artifact validators and the final changed-path audit cover only this child; the durable commit is reported in the worker completion signal.

### Summary

The design stage took the Phase 0 trivial-pass fast path because the shaped child has no UI, domain, design-required, contract-decision-required, or open-contract-decision signal. It emitted only the minimal Plan hand-off and stopped before plan; the missing completion lease is the sole registration blocker.

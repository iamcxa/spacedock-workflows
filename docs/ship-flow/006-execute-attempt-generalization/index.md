---
id: "006-execute-attempt-generalization"
title: "Execute attempt generalization"
pattern: shaped-child
parent_pitch: "006"
depends-on: ["006-plan-attempt-recovery"]
affects_ui: false
harvest_required: true
time_budget: 2h
layout: folder
status: sharp
stage_outputs:
  shape: shape.md
---

### Vertical Slice

Adopt the proven generic attempt seam in execute, route exhaustion before worker creation, and use #21 once as UAT without turning it into a compatibility program.

## Acceptance criteria

- **AC-1 — Execute adopts the already-proven generic attempt seam without a parallel implementation.**
  Verified by: a focused execute integration test exercises the shared attempt contract and no execute-only lifecycle duplicate is introduced.
- **AC-2 — Exhaustion routes without dispatching any worker.**
  Verified by: at threshold + 1 the route is terminal and worker, lease, attempt, and envelope counters all remain zero.
- **AC-3 — #21 is exactly one unchanged one-off UAT.**
  Verified by: one post-landing run consumes the seam while its preserved plan/evidence remains unchanged; no XFAIL registry, future-RED registry, or dispatcher repair is added.

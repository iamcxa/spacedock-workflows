---
id: "006-plan-attempt-recovery"
title: "Plan attempt recovery"
pattern: shaped-child
parent_pitch: "006"
depends-on: ["006-plan-attempt-vertical"]
affects_ui: false
harvest_required: true
time_budget: 4h
layout: folder
status: sharp
stage_outputs:
  shape: shape.md
---

### Vertical Slice

Recover or replay the proven plan attempt seam so one interrupted return produces one terminal contribution and never dispatches a duplicate worker.

## Acceptance criteria

- **AC-1 — Plan crash recovery and replay produce exactly one terminal contribution.**
  Verified by: focused crash-boundary tests replay the same authoritative attempt and observe a single terminal event and a single cumulative-duration contribution.
- **AC-2 — Recovery produces zero duplicate dispatches.**
  Verified by: worker/envelope counters remain zero while recovery reconciles a returned attempt, including replay after the terminal commit.
- **AC-3 — Resume/replay preserve attempt authority and fail closed on conflicting evidence.**
  Verified by: focused tests preserve attempt identity, clock, lease, ref, and returned bytes; mismatches leave authoritative state unchanged.

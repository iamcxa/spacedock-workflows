---
title: Advance-epic child fixture entity (not yet dispatch-eligible)
status:
source: fixture
started:
completed:
verdict:
score:
worktree:
issue:
pr:
id: "900.2"
parent_pitch: "900"
depends-on: ["900.1"]
---

Fixture entity: draft (not shaped, not `sd:approved`), so it is never
dispatch-eligible in this test — isolates the `advance` mechanism (dag-waves
readiness recompute) from the separate dual-key eligibility gate.

---
title: Advance-epic child fixture entity (not yet dispatch-eligible)
status: draft
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
readiness recompute) from the separate dual-key eligibility gate. The status
must be a non-empty `draft` (not blank): dag-waves' TSV computation uses awk
default field splitting, which collapses an empty status column and mis-reads
the deps column as the status.

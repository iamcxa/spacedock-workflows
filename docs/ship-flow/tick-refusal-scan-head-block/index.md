---
title: Fix tick refusal scanning head-block
status: design
issue: "#82"
worktree: .worktrees/spacedock-ensign-tick-refusal-scan-head-block
started: 2026-07-20T01:59:17Z
---

A refusal consumes the tick's single bounded action and refusals are not deduped/backoff-cached, so the eligibility scan re-refuses the alphabetically-first dormant entity every beat and never reaches later eligible entities (20:15+20:20 identical refusal beats on 2-deterministic-manual-adopter-routing while shaped+approved no-dangling-guard-qualifier-precision sat waiting). Fix: refusals are scan-events not the beat's action (batch-emit, then dispatch the first eligible in the same beat) + refusal dedup window. This blocked hackathon-2's live finale.

## Stage Report: shape

- DONE: Ship-Flow shape output separates refusal logic into three seams: scan-event emission (no-op dispatch candidate), refusal dedup window, and first-ready dispatch in same beat
  `shape.md` §Acceptance Criteria maps AC-1 (batch scan-emit), AC-2 (dedup window via `entity_in_backoff` broadening), AC-3 (two-phase collect-then-act preserving first-eligible dispatch) to three EXISTS_BROKEN seams cited by file:line in the layer trace.
- DONE: Defined acceptance criteria for refusal batching (all refusals emit before any dispatch decision) and dedup (prevent re-refusing same entity within N beats)
  AC-1 fixture: 3 refusing + 0 eligible → 3 distinct refusal events + no-op; AC-2 fixture: 1 refusing, 3 sequential ticks within window → tick-1 refusal + ticks 2/3 no-op with dedup marker; dedup key `(slug, reason)` DC-4 so reason changes re-emit (not spam).
- DONE: Shaped the entity boundary: scheduler.sh fix only; no tick controller refactor or rollup changes
  DC-1 + Size/Out-of-Scope pins fix to `ship-flow-scheduler.sh` (Precedence-2 loop body + `entity_in_backoff`) only; rollup awk, reconciler, adapter, events schema, and upstream `spacedock` binary explicitly excluded; concurrent finding (`dor_pass()` sidecar-only DoR gate) surfaced for FO decision but deferred to a separate future todo.

### Summary

Shaped as EXISTS_BROKEN seam-hardening (reverse-recovery layer-trace: 3
WORKING + 3 EXISTS_BROKEN + 0 MISSING → no greenfield, no new canonical
store, no schema change). Bug reproduced deterministically in the current
worktree against the live entity fixtures (2026-07-20T02:09Z); the 2h25m
finale spam of identical `not-shaped` refusals on
`2-deterministic-manual-adopter-routing` was confirmed against
`.ship-flow-scheduler-events.jsonl`. A concurrent finding —
`no-dangling-guard-qualifier-precision` was actually blocked by
`dor-stale-shape` (a `dor_pass()` gate that only recognises `shape.md`
sidecar files, not inline-body shape entities) — is surfaced explicitly for
the FO with a recommended follow-up todo, but held out of this entity's
scope per the "scheduler.sh fix only" boundary. Each of the three
captain-named ACs pairs a mechanism to the specific finale symptom it
prevents; five typed DCs (structural + behavioral + interface) hand off to
design with recommendations already flagged; ROADMAP now-row move-from-Later
intent + canonical-doc impact (design.md delta authoring, no
INVARIANTS/ARCHITECTURE/PRODUCT change) recorded for ship.

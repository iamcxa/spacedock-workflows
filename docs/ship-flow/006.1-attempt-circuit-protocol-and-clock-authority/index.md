---
id: "006.1"
title: "Attempt circuit protocol and clock authority"
pattern: shaped-child
parent_pitch: "006"
external_id: "ASC-W1-PROTOCOL-CLOCK"
depends-on: []
affects_ui: false
layout: folder
status: plan
stage_outputs: {}
worktree: .worktrees/spacedock-ensign-006.1-attempt-circuit-protocol-and-clock-authority-lineage
started: 2026-07-22T05:53:21Z
---

Inherited slice of the captain-approved W1-W4 prerequisite after EM route=narrow at parent HEAD e800e54a68d06ef5bbdddbf238398b85a61b2645.

Source of truth: parent design commit 31ec710f7afde772a7d88e90eac9c3fa4661502b, approved plan commit c7b6a9f264a74b8101525faf2036e12f414aff61, and reviewed T0 RED commit a575a1f. Do not re-shape or change D1-D4.

Scope: implement only the exact plan/execute stage-attempt-v1 grammar, FO-issued stage_run_id/attempt_id/ordinal/ref/before/completion bindings, plan=1200s and execute=1800s portable monotonic clock behavior, fresh versus same-boot resume semantics, and frozen completion-v1 framing. Use the committed contract and clock RED suites; record RED before production edits. Out: history CAS, route policy, integration wiring, scheduler, unrelated stages, or #21 changes.

Done: contract and clock suites GREEN, completion-v1 exact fixtures remain byte-identical, non-plan/execute and foreign bindings fail closed, missing/unparseable/regressing clock identity cannot regain budget, and the helper is reviewed and committed with explicit paths.

## Stage Report: plan

- DONE: Produce a dependency-safe `plan.md` for only the protocol and clock-authority slice defined by 006.1; reuse the captain-approved parent design and the committed T0 contract/clock RED suites, without pulling in history, route, scheduler, integration, or `#21` scope.
  Two serial L5 tasks own only the helper plus bounded foreign-binding negatives in the committed contract suite; explicit NARROW guards exclude every W2-W4 path and test.
- DONE: Pin the durable baselines (`e62bc651ae2f5728a4a13a75bcbb234e26617cb0`, `a575a1f`, `31ec710`) and specify runnable RED/GREEN/REFACTOR steps, explicit-path ownership, completion-v1 byte preservation, and task-level review gates.
  The plan records exact source/test/completion hashes, two auditable TDD contracts, frozen `completion-v1.sh` SHA-256, serial ownership, and per-task PROCEED/NARROW checks.
- DONE: Pass the TDD ledger and plan validators plus a fresh adversarial self-review; return `NARROW` or `BLOCKED` if completing W1 requires any W2-W4 behavior.
  Persisted ledger passes with 2 records; C4/C8/C15, placeholders, ownership, dependency, and diff gates pass after two review iterations. Verdict: PROCEED for independent W1; execute routes NARROW on W2-W4 dependency or BLOCKED on unresolved inherited C14 failure.

### Summary

The 006.1 plan is complete and stays inside the born-shaped W1 protocol/clock boundary. It preserves the reviewed RED baseline and frozen completion bytes, while making the current inherited C14 branch-history signal explicit instead of treating it as a product regression.

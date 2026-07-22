---
id: "006.1"
title: "Attempt circuit protocol and clock authority"
pattern: shaped-child
parent_pitch: "006"
external_id: "ASC-W1-PROTOCOL-CLOCK"
depends-on: []
affects_ui: false
layout: folder
status: execute
stage_outputs: {}
worktree: .worktrees/spacedock-ensign-006.1-attempt-circuit-protocol-and-clock-authority-lineage
started: 2026-07-22T05:53:21Z
---

Inherited slice of the captain-approved W1-W4 prerequisite after EM route=narrow at parent HEAD e800e54a68d06ef5bbdddbf238398b85a61b2645.

Source of truth: parent design commit 31ec710f7afde772a7d88e90eac9c3fa4661502b, approved plan commit c7b6a9f264a74b8101525faf2036e12f414aff61, and reviewed T0 RED commit a575a1f. Do not re-shape or change D1-D4.

Scope: implement only the exact plan/execute stage-attempt-v1 grammar, FO-issued stage_run_id/attempt_id/ordinal/ref/before/completion bindings, plan=1200s and execute=1800s portable monotonic clock behavior, fresh versus same-boot resume semantics, and frozen completion-v1 framing. Use the committed contract and clock RED suites; record RED before production edits. Out: history CAS, route policy, integration wiring, scheduler, unrelated stages, or #21 changes.

Done: contract and clock suites GREEN, completion-v1 exact fixtures remain byte-identical, non-plan/execute and foreign bindings fail closed, missing/unparseable/regressing clock identity cannot regain budget, and the helper is reviewed and committed with explicit paths.


---
id: "006.2"
title: "Attempt circuit crash-safe history and replay"
pattern: shaped-child
parent_pitch: "006"
external_id: "ASC-W2-HISTORY-REPLAY"
depends-on: ["006.1", "006-execute-attempt-generalization"]
affects_ui: false
layout: folder
status: plan
stage_outputs: {}
---

Dependent W2 slice of the same approved design. Start only from the merged predecessor output and bind its exact predecessor commit OID in plan/execute evidence.

Source of truth: parent design D3 at commit 31ec710f7afde772a7d88e90eac9c3fa4661502b and reviewed history RED suite from a575a1f. Preserve W1 bytes and APIs.

Scope: implement exact returned sidecar write, WAL returned flip, passed-folder completion checkpoint/reconcile/lease cleanup, terminal history plus tracked exact-return sidecar temporary-index ref CAS, post-CAS path-only reconcile, cleanup/replay, common-Git-dir entity+stage exclusion, provisional adoption, conflicts, and dirty index/worktree preservation. Non-passed and flat attempts terminalize without completion-v1. Out: routing policy, report/schema wiring, scheduling, or test reductions.

Done: every injected crash/lease/CAS boundary executes and passes; replay contributes one terminal event and duration; sibling worktrees cannot steal authority; mismatched evidence fails closed unchanged; unrelated dirt survives; reviewed explicit-path commit.

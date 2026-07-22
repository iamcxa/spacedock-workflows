---
id: "006.1"
title: "Attempt circuit protocol and clock authority"
pattern: shaped-child
parent_pitch: "006"
external_id: "ASC-W1-PROTOCOL-CLOCK"
depends-on: []
affects_ui: false
layout: folder
worktree: .worktrees/spacedock-ensign-006.1-attempt-circuit-protocol-and-clock-authority-lineage
started: 2026-07-22T05:53:21Z
status: execute
stage_outputs:
  plan: plan.md
  execute: execute.md
---

Inherited slice of the captain-approved W1-W4 prerequisite after EM route=narrow at parent HEAD e800e54a68d06ef5bbdddbf238398b85a61b2645.

Source of truth: parent design commit 31ec710f7afde772a7d88e90eac9c3fa4661502b, approved plan commit c7b6a9f264a74b8101525faf2036e12f414aff61, and reviewed T0 RED commit a575a1f. Do not re-shape or change D1-D4.

Scope: implement only the exact plan/execute stage-attempt-v1 grammar, FO-issued stage_run_id/attempt_id/ordinal/ref/before/completion bindings, plan=1200s and execute=1800s portable monotonic clock behavior, same-boot nonterminal suspend/resume authority, fail-closed clock-loss detection, and frozen completion-v1 framing. Use the committed contract and clock RED suites; record RED before production edits. Durable interrupted terminalization, continuation accounting, history/CAS/replay, and route policy stay with 006.2/006.3. Out: integration wiring, scheduler, unrelated stages, or #21 changes.

Done: the pre-existing contract baseline is GREEN before seven independently selected foreign-binding REDs are recorded and closed; the W1 nonterminal clock mode is GREEN; completion-v1 exact fixtures remain byte-identical; missing/unparseable/foreign/regressing clock identity cannot regain budget or mutate nonterminal authority; and the helper is reviewed and committed with explicit paths. 006.2 owns durable `interrupted` terminalization and history/replay; 006.3 owns fresh-continuation accounting and route-out behavior.

## Stage Report: plan

- DONE: Produce a dependency-safe `plan.md` for only the protocol and clock-authority slice defined by 006.1; reuse the captain-approved parent design and the committed T0 contract/clock RED suites, without pulling in history, route, scheduler, integration, or `#21` scope.
  Two serial L5 tasks own only the helper plus bounded foreign-binding negatives in the committed contract suite; explicit NARROW guards exclude every W2-W4 path and test.
- DONE: Pin the durable baselines (`e62bc651ae2f5728a4a13a75bcbb234e26617cb0`, `a575a1f`, `31ec710`) and specify runnable RED/GREEN/REFACTOR steps, explicit-path ownership, completion-v1 byte preservation, and task-level review gates.
  The plan records exact source/test/completion hashes, two auditable TDD contracts, frozen `completion-v1.sh` SHA-256, serial ownership, and per-task PROCEED/NARROW checks.
- DONE: Pass the TDD ledger and plan validators plus a fresh adversarial self-review; return `NARROW` or `BLOCKED` if completing W1 requires any W2-W4 behavior.
  Persisted ledger passes with 2 records; C4/C8/C15, placeholders, ownership, dependency, and diff gates pass after two review iterations. Verdict: PROCEED for independent W1; execute routes NARROW on W2-W4 dependency or BLOCKED on unresolved inherited C14 failure.

### Summary

The 006.1 plan is complete and stays inside the born-shaped W1 protocol/clock boundary. It preserves the reviewed RED baseline and frozen completion bytes, while making the current inherited C14 branch-history signal explicit instead of treating it as a product regression.

### Feedback Cycles

- Cycle 1, plan gate at `654ab19`: SO/EM route `block` with high confidence. FO repaired the inherited C14 lineage non-destructively at `8142856`; `CI=true bash plugins/ship-flow/bin/check-invariants.sh` is now GREEN. Return to plan for the two remaining defects: make every new foreign-binding negative demonstrate an independent RED rather than being masked by the missing-helper guard, and narrow T2 clock-loss claims so durable interruption/history/route behavior remains owned by 006.2/006.3.

## Stage Report: plan

- DONE: Repair T1 so each newly planned foreign-binding negative has an independently observable RED after the pre-existing contract baseline can run; do not accept the missing-helper guard as evidence for cases it masks.
  T1 now freezes the missing-helper probe as baseline-only, requires baseline GREEN, then runs seven named selectors independently for stage-run/ref/before/worker-completion/worker/lease/attempt binding REDs before production hardening.
- DONE: Narrow T2 and the entity completion language to W1-owned nonterminal clock authority only; keep durable interrupted terminalization, continuation accounting, history, and route behavior explicitly assigned to 006.2/006.3.
  T2 now owns only budgets, elapsed authority, same-boot nonterminal resume, and byte-preserving clock-fault refusal; 006.2 owns durable interruption/history/replay and 006.3 owns continuation accounting/route-out.
- DONE: Re-run the TDD ledger, plan validators, focused existing RED evidence, C14/invariants, and adversarial self-review on clean lineage `8142856`; append a fresh final `Stage Report: plan` with a proceed/narrow/blocked judgment.
  Persisted ledger passes with 2 records; focused suites reproduce only their current missing-helper RED; C4/C8/C14/C15, full invariants, Node 79/79, version-triple, no-dangling, frozen completion hash, line budget, and explicit-path audit pass.

### Summary

Route judgment: **PROCEED** for independent SO/EM re-review of the bounded W1 plan. Execute must return **NARROW** before durable interruption/history/continuation/route work, and **BLOCKED** if clean-lineage C14 or another assigned repository gate regresses.

### Feedback Cycles

- Cycle 2, plan re-gate at `691e1d6`: SO/EM route `return` with high confidence. The persisted T1 ledger decodes to `STAGE_ATTEMPT_CONTRACT_CASE=\"$CASE\"`, so shell evaluation can pass literal quote bytes and make every selector fail as unknown. Repair only command serialization, regenerate the ledger, and prove the seven decoded selector tokens reach their named cases without helper/fixture/unknown-selector masking. Preserve lineage, T2 scope, and frozen completion bytes.

## Stage Report: plan

- DONE: Correct only the persisted T1 RED command serialization so decoded shell receives the seven exact selector tokens without literal quote bytes; keep safe handling for the fixed allowlist.
  T1 now persists `STAGE_ATTEMPT_CONTRACT_CASE=$CASE` inside the closed seven-token `for` list; no T2, task-topology, or implementation command changed.
- DONE: Regenerate and validate the TDD ledger, then demonstrate from decoded output or an equivalent hermetic probe that all seven selectors reach their named cases rather than an unknown-selector, helper, or fixture guard.
  Both ledger validators report `status=pass records=2`; the decoded-command probe reaches baseline plus all seven named cases in order and reports `0 unknown/helper/fixture guards`.
- DONE: Preserve clean lineage, T2's nonterminal-only boundary, frozen completion-v1 hash, and W2-W4 exclusions; append a fresh final `Stage Report: plan` and commit only plan-owned paths.
  C4/C8/C14/C15 and full invariants pass, Node tests are 79/79, version/no-dangling gates pass, completion-v1 remains `a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10`, and product/W2-W4 paths are unchanged.

### Summary

Route judgment: **PROCEED** for independent SO/EM re-review of the repaired W1 plan. Execute must still return **NARROW** before durable interruption/history/continuation/route work and **BLOCKED** if clean-lineage C14 or another assigned repository gate regresses.

## Stage Report: execute

- DONE: Deliver only the exact 006.1 W1 protocol and nonterminal clock-authority slice with independently observed RED-before-GREEN evidence for T1 and T2.
  T1=`920d950` and T2=`5ceebf4`; controller-observed REDs precede final contract 40/40, nonterminal 26/26, and return-budget 6/6 GREEN.
- DONE: Preserve completion-v1 bytes and keep durable interruption, history/replay, continuation accounting, route policy, integration wiring, scheduler, and #21 out of scope.
  Frozen SHA remains `a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10`; full-suite deferred failures are named in `execute.md`, with no owning path added.
- DONE: Land one explicit-path commit per serial task, produce truthful execute.md evidence, and return NARROW/BLOCKED instead of absorbing 006.2-006.4 behavior.
  Implementation history contains exactly two commits with T1/T2 path ownership, followed only by the required execute artifact/report commit; cross-review returned PROCEED.

### Summary

Execute completed the bounded W1 protocol and nonterminal clock-authority slice with exact-byte, concurrency, unsigned-clock, and strict-budget hardening. The handoff remains NARROW at the 006.1 boundary: all durable terminal/history/continuation/route/integration behavior stays with 006.2-006.4.

## Stage Report: execute

- DONE: Preserve the product history and exact two implementation commits (`920d950` T1, `5ceebf4` T2); make zero production/test changes.
  Receipt repair changes only this entity index and `execute.md`; the implementation range and frozen completion helper are unchanged.
- DONE: Repair only `execute.md` and the final `## Stage Report: execute` truth surface: explicitly mark the prior 181-minute receipt partial/INCOMPLETE, then add a fresh bounded receipt-repair epoch with its own start/end/duration and truthful result.
  The prior epoch is now `status: partial` with an explicit INCOMPLETE marker; the fresh epoch records independent timing and `repair_result: passed`.
- DONE: In this fresh epoch, run the smallest sufficient current checks that prove W1 and record actual outputs/counts; name deferred 006.2-006.4 failures without running their full suites.
  Fresh evidence: 40/40 contract, 26/26 nonterminal, 6/6 return-budget, frozen SHA + compatibility, C1-C18, Node 79/79, version 0.9.0, no-dangling 8 patterns, and clean diff/scope checks; deferred suites are named in `execute.md`.

### Summary

The W1 product result remains intact, but the original 181-minute execute receipt is process-incomplete and no longer claims `passed`. This bounded repair publishes a separately timed, evidence-backed receipt without completion registration or verify advancement.

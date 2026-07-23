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
status: ship
stage_outputs:
  shape: shape.md
  design: design.md
  plan: plan.md
  execute: execute.md
  verify: verify.md
  review: review.md
  ship: ship.md
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

- DONE: Register the already-validated Phase 0 trivial-pass design through completion-v1 at the repaired eligible child HEAD.
  Completion registration published the canonical `design.md` stage output at `230531e5` after the bounded frontmatter repair restored exact eligibility.
- DONE: Keep the one-plan-caller boundary explicit; preserve `548b338` protocol/clock evidence without pulling recovery, execute, scheduler, dispatcher, `#21`, or sibling scope.
  The durable receipt repair changed only this child index; implementation, tests, product code, lease state, and sibling entities remain outside this report update.

### Summary

The already-validated Phase 0 trivial-pass design completed successful completion reconciliation at `230531e5`. The hand-off remains bounded to one real plan caller and preserves the `548b338` protocol/clock evidence without widening into recovery, execute, scheduler, dispatcher, `#21`, or sibling scope.

## Stage Report: plan

Checklist accounting: **3 DONE, 0 SKIPPED, 0 FAILED**.

- DONE: Produce an executable `plan.md` for one real plan caller consuming one bounded fresh attempt end to end, with typed caller-owned authority and a focused integration test.
  Evidence: `plan.md` defines one serial T1 across the real FO caller, completion lifecycle, attempt helper, and `test-stage-wiring.sh --plan-attempt`; `tdd-ledger.txt` and `tdd-ledger.jsonl` persist `status=pass records=1` for that RED/GREEN contract.
- DONE: Name exact owned files and changed-surface RED/GREEN checks first; reserve one full suite for final integrated HEAD and classify unrelated failures without widening scope.
  Evidence: `plan.md` names the four exact owned paths, focused RED/GREEN and refactor commands, then reserves the all-gates command for final integrated HEAD with unrelated failures recorded and deferred.
- DONE: Include Canonical Doc Actions and preserve the Phase A boundary: no recovery, execute generalization, scheduler, dispatcher, `#21`, XFAIL/future-RED, sibling, or unrelated repair work.
  Evidence: `plan.md` carries the three-row Canonical Doc Actions table and an explicit NARROW boundary excluding every deferred surface above.

### Summary

The reviewed plan and persisted TDD ledger completed successful completion reconciliation at `ae470adf`. The executable hand-off covers one bounded fresh plan attempt through typed caller-owned authority and focused integration proof, with changed surfaces verified first and the Phase A exclusions preserved.

## Stage Report: verify

- DONE: Prove AC-1 and AC-2 at the real plan caller with independent focused checks: exactly one fresh attempt, dispatch, authoritative return, terminal contribution, and typed caller-owned authority across the lifecycle seam.
  Fresh `test-stage-wiring.sh --plan-attempt` produced exact 1/1/1 counts plus one history duration, one byte-exact sidecar, and clean private state; adjacent authority/fault probes all exited 0.
- DONE: Verify completion lifecycle and faults, materially affected attempt contract and clock selectors, C14/history invariants, frozen completion-v1 bytes, and diff cleanliness without repeating the full repository suite already green at 0b7d2133.
  Focused lifecycle/fault, attempt grammar, five retained clock-selector, C14/corpus, Bash syntax, ShellCheck, frozen-byte, and diff checks passed; only report/state commits follow `0b7d2133`.
- DONE: Judge scope/minimality: treat clock cleanup and dormant-future test deletions as inventory hygiene; reject any crash/replay, recovery, execute generalization, scheduler, dispatcher, #21 behavior, sibling, or automatic-wave follow-up scope.
  The exact nine-path execute set contains only four owned seam surfaces, the execute report, and four authorized test-inventory changes; excluded product paths are untouched.

### Summary

Independent bounded verification passed AC-1 through AC-3 with no current-scope defect. `verify.md` records PROCEED, explicit non-UI runtime-UAT not-applicability, reused full-suite evidence at unchanged product/test HEAD `0b7d2133`, and the dispatch-required no-fan-out panel degradation.

## Stage Report: ship

- DONE: Confirm verify is legitimately green at the exact child head, the origin/main-to-head diff matches the shaped vertical scope, and every excluded recovery/generalization/sibling surface remains absent.
  Focused caller/lifecycle/authority, static, frozen-byte, diff, and C14 checks pass; `0b7d2133` remains the unchanged product/test receipt, while only shaped sibling scaffolds exist.
- DONE: Consume Canonical Doc Actions narrowly: update ARCHITECTURE.md only if the planned decision-row change is still required; give explicit skip rationales for PRODUCT.md, README.md, ROADMAP.md, and umbrella closeout without starting sibling work.
  `041db600` adds the one required decision row; `review.md` records all three canonical skips, README skip, and open-umbrella rationale, with the canonical checker passing 7/7 outcomes.
- DONE: Produce a compliant review.md with PROCEED only if contribution/canonical-sync checks pass, a slim PR draft reference, exact head/base evidence, and a clear ship-final handoff; do not push or create/merge a PR.
  `c67db74f` records PROCEED after the contribution gate and exact-range review, keeps PR publication unperformed, and hands composition/publication back to FO ship-final.

### Summary

The plan-attempt vertical is PR-ready with no current-scope finding and no product/test drift after the valid full-suite receipt. Canonical sync is complete, excluded future work remains dormant, and FO retains all PR, merge, and completion-publication authority.

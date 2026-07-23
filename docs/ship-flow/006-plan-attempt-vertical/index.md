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
worktree:
started: 2026-07-23T00:13:19Z
status: done
stage_outputs:
    shape: shape.md
    design: design.md
    plan: plan.md
    execute: execute.md
    verify: verify.md
    review: review.md
    ship: ship.md
pr: "#94"
verdict: PASSED
completed: 2026-07-23T05:07:22Z
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

## Stage Report: ship (cycle 2)

- DONE: Resolve live origin/main and remote-head state, then push the exact child lineage without force; if the historical branch ref conflicts, push to a new remote head ref without renaming the local branch.
  Live `origin/main` resolved to `2ffee4b0` and is an ancestor of the child lineage; the live child ref was absent, so the exact local lineage was pushed normally to `spacedock-ensign/006-plan-attempt-vertical` without force or branch renaming.
- DONE: Compose the PR body once from canonical shape/verify/execute/review sources, pass privacy/title/coherence/citation gates, and create a PR to main with the exact gated body file.
  The 59-line body passed zero-hit privacy, title, section, verbatim-source, SHA-citation, coherence, lint, and C15 gates at SHA-256 `74e38f09`; GitHub created PR #94 against `main` from those exact bytes.
- DONE: Confirm body/head/base remotely, persist PR metadata and finalize ship.md, push the final exact HEAD, run read-only mergeability/status checks, and stop PR-ready without merge or auto-merge.
  `persist-pr-metadata.sh` confirmed PR #94 and its body before writing the active child only; `ship.md` records `awaiting-pr-review` and `#94`; the remote head matched the pushed local head, while the read-only merge helper reported `BLOCKED` because invariants remained in progress, so no Ready/reviewer/merge automation ran.

### Summary

PR #94 now carries the exact reviewed plan-attempt vertical against `main`, with active-child metadata and the compact ship artifact synchronized to the confirmed remote PR. Publication stopped at the open, unmerged PR-ready boundary: contribution-contract and GitGuardian checks passed, invariants were still running, and no merge, auto-merge, closeout, archive, controller mutation, or post-merge work occurred.

---
title: Fix tick refusal scanning head-block
status: design
issue: "#82"
worktree: .worktrees/spacedock-ensign-tick-refusal-scan-head-block
started: 2026-07-20T01:59:17Z
---

The tick reports only the FIRST-encountered refusal per beat and refusals have no dedup/backoff (`entity_in_backoff` matches `event=blocked` only), so the events log shows a monotonous spam of the alphabetically-first entity's refusal while every other dormant entity's true refusal reason is silently discarded (66/119 duplicate `not-shaped` beats on 2-deterministic-manual-adopter-routing masked no-dangling-guard-qualifier-precision's real `dor-stale-shape` block for 2 days). Corrected premise (shape.md layer trace): the Precedence-2 scan already visits every entity and already dispatches the first eligible in the same beat — this is an observability + dedup defect, not a traversal defect. Fix: batch-emit all scan refusals as observability records, dedup by `(slug, reason)` window, keep first-eligible same-beat dispatch explicit and test-pinned. This masked hackathon-2's live finale blocker.

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

## Stage Report: design

- DONE: Contract decision 1 resolved and recorded in design.md — event-cardinality vs one-event-per-tick (script header L1-14): chose (a) revise contract to one-primary-ACTION-event with refusals as observability records; AC-1/AC-3 fixture assertions restated to match
  design.md §1: rejected (b)/(c) with reasons — (b) aggregation contradicts AC-1's "3 distinct refusal events"; (c) log-only breaks eligibility L64 `"event":"refusal"` on stdout (emit_event writes stdout unconditionally). Header L6-8 revised text named.
- DONE: Contract decision 2 resolved — rollup interventions semantics: pin current per-line count as intended ("distinct entity-refusal observations", not paused-beats); named the pinning assertion
  design.md §2: count-distinct-tick_id would regress the multi-entity visibility the fix restores; dedup window bounds inflation. Pin = new `run_multi_refusal_beat_intervention_count_case` in test-ship-flow-scheduler-rollup.sh asserting `interventions (blocked + refusal): 3` for a 2-refusal-same-tick_id + 1-blocked fixture.
- DONE: design.md names every existing test file/assertion that moves; no existing assertion left contradicting the chosen contract
  design.md §4: eligibility (single-entity refusal cases compatible via substring), backoff (blocked path unchanged), fullcycle (leg-1 gains child refusal, leg-3 dispatch preserved ONLY by post-eval reason-scoped dedup), rollup, reconcile, idempotence all cited by file:line; new multi-entity fixtures mirror two_entity_workflow. Baseline of all four run green (exit 0) 2026-07-20.

### Summary

Design PROCEED. Both blocking contract decisions resolved: (1) event cardinality → option (a), refusals reclassified as observability records emitted before the single primary ACTION event (the only option consistent with both the shape-authored AC-1/AC-3 fixtures and the existing eligibility suite's stdout assertions); (2) rollup interventions → pin per-line count as "entity-refusal observations" (per-tick_id would re-hide the multi-entity signal the fix exists to restore). Load-bearing design constraint discovered and disproof-verified: refusal dedup MUST be post-eval, reason-scoped, case-1|2-only — a naive pre-eval slug-scoped `entity_in_backoff` refusal skip breaks test-ship-flow-scheduler-fullcycle.sh leg-3 (child refuses `not-shaped` in leg 1, must dispatch in leg 3). design.md written to the entity folder; scope unchanged (scheduler.sh only, no schema).

### Revision note (cycle 1 — REVISE bounded, codex gaps folded in)

Direction unchanged (option (a), per-line rollup, post-eval reason-scoped dedup). Three completeness fixes, all verified against primary sources before editing: (1) §1 revised header wording now accommodates the shipped reconcile→advance double-emit (scheduler.sh:591-594,660; fullcycle L167-169 requires both) — the old "exactly one JSON Lines event" text was already false pre-batching; AC-1/2/3 fixtures unaffected (Precedence-2 beats only). (2) Contract-text delta now names scheduler.sh:522-525 (AC-3b comment citing the old contract) as delta site 2; historical repeats in l3-scheduler-tick/design.md:73-76,139-150, tick-hardening/design.md:108-115,203, tick-hardening/index.md:70-83 recorded in §5 as unedited superseded snapshots. (3) §5 records the "events log is audit-only, never read to decide" contract supersession (first superseded by tick-hardening AC-4 `entity_in_backoff`, PR #81; this design extends the same reading to refusals) with a narrowed surviving contract, folded into the INVARIANTS candidate; the "no canonical-doc change" claim corrected — design.md carries two durable contract-revision notes.

## Stage Report: plan

- DONE: Every code-bearing task carries RED-before-GREEN naming the exact test file; all delta sites from design.md named (header L6-8, comment L522-525, two-phase batch-emit loop, `entity_in_backoff` (slug,reason) broadening, RUNBOOK.md:24-25, both contract-revision notes)
  plan.md Task 1 (`test-ship-flow-scheduler-refusal-batch.sh`, 4 RED cases incl. reason-change sub-case) + Task 2 (`test-ship-flow-scheduler-rollup.sh` pin) + Task 4 (`check-invariants.sh --check refusal-observability-record`) carry full RED/GREEN; Task 3 (header/comment/RUNBOOK prose) is explicitly RED/GREEN-exempt with cited rationale (design.md §4: no existing assertion pins this text as a line count) mirroring tick-hardening Task 8's identical precedent for its own RUNBOOK edit.
- DONE: Plan preserves revised contract semantics exactly (one primary action/tick w/ reconcile→advance chain unchanged, refusals as pre-action observability records, post-eval reason-scoped case-1|2-only dedup, rollup per-line pin); new fixtures mirror `two_entity_workflow`
  plan.md "Contract semantics preserved" section + Task 1's `three_entity_workflow` helper (explicit mirror) + Task 2's named `run_multi_refusal_beat_intervention_count_case`.
- DONE: Canonical Doc Actions section covers ROADMAP now-row, both contract-revision notes (explicit mapping table), and the INVARIANTS candidate as an execute-stage hard condition (Principle 18, mirrors Principle 17/check C16 structure); a worker-drafted verify-gate brief is listed as an explicit deliverable the FO forwards but does not author
  plan.md Task 4 (Principle 18 + check-invariants.sh C18), Task 5 (Canonical Doc Actions table + delta-site mapping table), "Verify-gate handoff" section.

### Summary

Read shape.md (incl. FO takeover amendment + citation correction), design.md at 4ff843f in full (280 lines, all 5 sections), and decisions.md — which lives only on `iamcxa/muscat-v1` (a separate, more-advanced state track this origin/main-based worktree predates; read via `git show iamcxa/muscat-v1:...` without merging or switching branches, per the dispatch's "work ONLY in this worktree" constraint). decisions.md's design-gate review (SO-EM PROCEED 88 + codex cross-vendor SAFE, CONVERGED, captain conditional grant) named two execute-stage hard conditions — an INVARIANTS.md candidate and a RUNBOOK.md:24-25 wording fix — that shape's original "3-4 edits" appetite estimate didn't price in; plan.md flags this size delta explicitly rather than absorbing it silently. Verified every design.md citation (line numbers, function names, existing fixture entities, dead `--epic` code path) against the live `ship-flow-scheduler.sh`, `check-invariants.sh`, and `INVARIANTS.md` before writing plan.md's 5-task breakdown: Task 1 (core two-phase batch-emit + reason-scoped dedup mechanism, 4 RED cases against a new `test-ship-flow-scheduler-refusal-batch.sh`), Task 2 (rollup interventions per-line pin), Task 3 (prose-only contract-text sync across 3 sites), Task 4 (INVARIANTS Principle 18 + check-invariants.sh C18, folding both contract-revision notes), Task 5 (Canonical Doc Actions). Baseline confirmed: all 8 existing `test-ship-flow-scheduler-*.sh` suites green before authoring. No code was written or modified — plan stage only.

## Stage Report: execute

- DONE: RED observed before GREEN
  Task-1's 4 RED cases (incl. reason-change re-emit sub-case) reproduced failing against the unmodified scheduler before implementation; RED->GREEN evidence per task in execute.md; Task-3 prose edits exempt per plan.md's cited rationale (design.md §4: no existing assertion pins the contract text as a line count).
- DONE: Full local gate before handoff
  All 9 scheduler suites (8 existing + new refusal-batch) green, `check-invariants.sh` (C1-C18, incl. new C18) green, `check-no-dangling.sh` + `check-version-triple.sh` green; revised contract semantics preserved exactly (verified via fullcycle leg-3 canary + eligibility/backoff regression); see execute.md's "Full local gate" section for full evidence incl. a CI-sim spot-check.
- DONE: All 5 plan tasks land on this main-lineage branch; Canonical Doc Actions fully consumed; worker-drafted verify gate-brief produced
  Commits `193196f`/`d7a117d`/`021b0e1`/`62c83fb`/`bad7db7` (Tasks 1-5); ROADMAP now-row, both contract-revision notes (Tasks 3+4), RUNBOOK.md:24-25, INVARIANTS Principle 18 + C18 all landed; gate-brief section in execute.md.

### Summary

Implemented plan.md's 5 tasks TDD-first on `spacedock-ensign/tick-refusal-scan-head-block` (branch targets `main`, not `muscat-v1`, per plan.md's Summary). Task 1 rewrote Precedence-2 as two-phase collect-then-act, fixing the head-block bug (RED reproduced the exact finale symptom: only the alphabetically-first refusal ever surfaced, and a later eligible entity silently discarded even that one). Task 2 pinned the rollup's per-line `interventions` semantics with zero code change. Task 3 synced 3 prose contract-text sites. Task 4 added INVARIANTS Principle 18 + check-invariants.sh C18 (the design gate's execute-stage hard condition), and along the way fixed a self-inflicted C15 artifact-verbosity violation on plan.md (documented as a deviation, tick-hardening-precedented). Task 5 added the ROADMAP Now-row (a deviation from the literal "move from Later" instruction, since no Later row exists on this main-lineage branch — also documented). Full local gate green throughout; a CI-sim spot-check surfaced a pre-existing, diff-unrelated `gh`-CLI-absence gap on 3 untouched Precedence-1 test files, named in execute.md as a finding for the verify-stage panel, not fixed (out of this entity's DC-1 scope). Time budget: well under the 1h15m allocation.

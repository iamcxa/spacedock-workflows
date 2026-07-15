---
id: ""
title: "Make debrief a native post-merge ship closeout"
status: verify
pattern: pitch
appetite: "medium-batch (1-2 weeks)"
shape_mode: mode-a
answers_density: high
affects_ui: false
design_required: true
contract_decision_required: true
domain: schema
source: "Captain directive 2026-07-15; PR #40/#41 dogfood closeout"
started: 2026-07-15T03:30:16Z
layout: folder
harvest_required: true
children: []
rabbit_holes: []
deleted_from_shape:
    - claim: "Use PR headRefOid or current main as the landing SHA"
      reason: "Rebase rewriting and concurrent main movement make both identities invalid."
    - claim: "Create a separate debrief stage or skill"
      reason: "The requested outcome belongs to the existing ship lifecycle and the stage-skill count is capped."
    - claim: "Classify closeout PRs by title or body prose"
      reason: "Editable prose cannot provide a mechanical recursion guard."
acceptance_outcome: "When an implementation PR becomes MERGED, one bounded FO startup or idle cycle produces the final debrief and compact ship receipt with real landing facts, a coherent done/PASSED archive, and exactly one Shipped ROADMAP row."
captain_bet: "When this ships, the captain expects a merged implementation PR to reach a debriefed, archived done state with its real landing SHA within one FO post-merge closeout cycle. If not, this pitch was wrong about the Layer 1 claim that debrief belongs to the ship lifecycle rather than an ad-hoc session ritual."
stated_assumptions:
    - id: A1
      claim: "Provider merge time plus a post-merge landing anchor, topology, PR commit count, and patch equivalence can identify the real landing set across all three strategies."
      verified_by: codebase-grep
      verification: "Disposable three-strategy topology probe plus live PR #13/#14/#40/#41 inspection."
      confidence_at_shape: 95
      criticality: critical
    - id: A2
      claim: "The existing reconciler can become a resumable closeout transaction without weakening fail-closed cleanup behavior."
      verified_by: design-contract
      verification: "Design must ratify the checkpoint and atomicity contract before plan."
      confidence_at_shape: 75
      criticality: critical
    - id: A3
      claim: "A persisted sentinel bound to implementation PR and entity identity can prevent recursive closeout."
      verified_by: design-contract
      verification: "Design must ratify sentinel location and validation semantics before plan."
      confidence_at_shape: 85
      criticality: important
pre_mortem:
    category: wrong-dcs
    one_liner: "All strategy fixtures pass, but non-atomic debrief, archive, and ROADMAP writes still force a second manual FO cycle after a crash."
stage_outputs:
    shape: shape.md
    verify: verify.md
worktree: .worktrees/spacedock-ensign-ship-stage-debrief-closeout
---

<!-- section:stage-artifact-links -->
| Stage | File |
| --- | --- |
| shape | [shape.md](shape.md) |
| design | [design.md](design.md) |
| plan | [plan.md](plan.md) |
| execute | [execute.md](execute.md) |
| verify | [verify.md](verify.md) |
<!-- /section:stage-artifact-links -->

<!-- section:problem -->
## Problem

Productize the manual PR #40/#41 closeout as
`ship-stage-debrief-closeout`. After an implementation PR is merged, one
bounded FO post-merge cycle must use GitHub's real `mergedAt` and landing facts
to produce the final debrief and compact ship receipt, advance `ship -> done`
with `PASSED`, archive the entity, move the ROADMAP row to Shipped, and
optionally create one closeout PR. A closeout PR must be mechanically
classified so its own merge cannot recurse into another closeout.
<!-- /section:problem -->

<!-- section:captain-bet -->
## Captain Bet

When this ships, the captain expects a merged implementation PR to reach a debriefed, archived done state with its real landing SHA within one FO post-merge closeout cycle. If not, this pitch was wrong about the Layer 1 claim that debrief belongs to the ship lifecycle rather than an ad-hoc session ritual.
<!-- /section:captain-bet -->

<!-- section:required-design-questions -->
## Required design questions

1. Pre-merge may prepare only a skeleton or intent; final debrief evidence must use post-merge `mergedAt` and the true landing SHA, never a rebase-rewritten PR-head SHA.
2. Runtime fixtures must cover rebase merge, squash merge, and merge commit, with reliable first/last landing commits even when main moves concurrently.
3. Final `ship.md` keeps the C15 cap and existing `pr:` number/body confirmation invariants. Terminal state, archive, and ROADMAP writes must be atomic or have an explicit crash-resume checkpoint.
4. Closeout classification must be a mechanical sentinel, not title guessing; startup, idle, and merge reruns must be idempotent.
5. Missing PR mirrors, missing ship.md, partial archive, or an already-updated ROADMAP must safely resume or fail closed with stable reasons; incoherent archives must never silently pass.
6. Preserve full debrief reconciliation/todo digest and the existing rule that todo body counts exclude balanced `<details>` content. Do not change C15 caps without separate captain evidence and approval.
<!-- /section:required-design-questions -->

<!-- section:acceptance-criteria -->
## Acceptance criteria

- **AC-1 Landing evidence:** Rebase, squash, and merge-commit runtime fixtures
  with concurrent main movement produce provider `mergedAt`, `base_before`, an
  ordered landing set, and correct first/last landing commits without retaining
  an invalid PR-head SHA or later main tip.
- **AC-2 One-cycle closeout:** One startup/idle cycle after the implementation
  PR reaches MERGED produces the schema-valid final debrief, compact final ship
  receipt, done/PASSED archive, and one ROADMAP Shipped row.
- **AC-3 Debrief fidelity:** Reconciliation and todo digest content remains
  complete, and existing balanced standalone `<details>` counting semantics are
  unchanged.
- **AC-4 Idempotency and recovery:** Repeating closeout at least twice and
  resuming after every durable write creates no duplicate debrief, ROADMAP row,
  archive, or PR; every partial state resumes or fails closed with a stable
  reason. Missing `review.md`/`ship.md` and incoherent stage-artifact state
  cannot terminalize.
- **AC-5 Recursion guard:** Merging the optional closeout PR does not create
  another closeout, proven by a persisted machine-readable sentinel rather
  than title or prose.
- **AC-6 Compatibility:** Existing ship-final PR-body binding,
  persist-pr-metadata, C14, C15, todo accounting, canonical-doc CAS, and
  worktree cleanup invariants remain green.
- **AC-7 Dogfood:** A frozen PR #40/#41 regression fixture reproduces the final
  manually reconciled state in one invocation without hand-editing index.md,
  ship.md, a debrief, or ROADMAP.md; the second invocation is a no-op.
<!-- /section:acceptance-criteria -->

<!-- section:scope-boundaries -->
## Scope boundaries

- Do not redo completed #20/#22/#28.
- Do not include #21 shape-confirm-instance-awareness.
- Do not touch C14 or RoboRev orphan worktrees.
- Do not post or modify upstream issues #24-#27.
- Do not hardcode Slack, Linear, or any specific task manager into core.
<!-- /section:scope-boundaries -->

<!-- section:shape-instructions -->
## Shape instructions

- Run the riskiest landing-SHA/range probe before composing the proposal.
- Default to `medium-batch`, `design_required: true`, and `contract_decision_required: true` unless evidence disproves them.
- Produce the shape artifact, sharpened ACs, explicit assumptions, one pre-mortem, and the ROADMAP row.
- Use runtime fixture evidence ahead of prose. Implementation workers later must follow TDD with observable RED before GREEN.
- Stop at the shape captain gate. Never self-approve.
<!-- /section:shape-instructions -->

<!-- section:shape-state -->
## Shape State

The formal outcome card, landing-evidence probe, acceptance contract,
assumptions, pre-mortem, canonical intent, and hand-off to design live in
[shape.md](shape.md). The captain-authored Bet above is preserved verbatim.
<!-- /section:shape-state -->

<!-- section:sharp-report -->
## Stage Report: shape

- DONE: Run and record a bounded read-only landing-evidence probe for rebase,
  squash, and merge-commit strategies with concurrent main movement. Provider
  `mergedAt` plus the landing anchor are authoritative; PR head and current
  main are rejected, and merge-commit exactness retains `base_before` plus the
  ordered landing set.
- DONE: Produce the formal medium-batch shape artifact and entity contract with
  sharpened ACs, explicit assumptions, one credible pre-mortem,
  `design_required: true`, `contract_decision_required: true`, validated
  `domain: schema`, and a ROADMAP Now row. The Captain Bet remains verbatim.
- DONE: Perform the independent seven-factor shape cross-review. Verdict is
  PROCEED: six factors PASS; reverse-audit WARN is absorbed by adding the prior
  missing-`review.md` lifecycle failure to the recovery matrix.
- BOUNDARY: No product code, tests, closeout behavior, issue state, workflow
  status, or captain gate state changed. Design owns five explicit contract
  decisions; the captain shape gate remains pending.
- status: passed
- stage_cost: one L0 probe worker, one independent reviewer, shape artifacts only

### Summary

Shaped native post-merge debrief closeout around a probe-backed landing
envelope, one-cycle value outcome, resumable recovery contract, and mechanical
recursion guard. The proposal is recommended for the captain gate and routes
to schema design if confirmed.

### Metrics

- status: passed
- duration_minutes: 20
- iteration_count: 0
- path: shape+sharp
- open_contract_decisions_count: 5
- domain_matches_count: 1
<!-- /section:sharp-report -->

## Stage Report: design

- DONE: Resolve the five shape handoff contract decisions through the schema-domain design route: landing-envelope proof grammar, closeout identity/ownership, resumable transaction boundaries, recursion sentinel, and merge-method ambiguity; preserve explicit trade-offs and stable fail-closed reasons rather than letting plan choose silently.
  `design.md` records D1-D5, a five-row trade-off table, exact proof/receipt schemas, recovery semantics, and one canonical stable-reason vocabulary.
- DONE: Emit schema-backed design.md with Schema Design Output, D{N} decision anchors, structured design_constraints, canonical PRODUCT/ARCHITECTURE context, artifact/dispatch manifest, and Hand-off to Plan; open_decisions must be empty for PROCEED or explicitly returned as PROMPT_CAPTAIN.
  Handoff schema and D-reference validators pass; all 12 constraints import, five decision anchors resolve, and `open_decisions: []`.
- DONE: Run the risk-gated design readiness check and fresh non-UI seven-factor cross-review, record full stage report/metrics and focused invariant evidence, and stop before plan or implementation unless the FO advances after the design verdict.
  Readiness returned PASS for schema+fmodel; fresh review corrected one reason-name VETO then returned PROCEED with all seven factors PASS; focused suites are 82/82, 10/10, and 19/19.

### Summary

Designed native post-merge closeout around a versioned `_closeouts/<closeout_id>.json` receipt, exact landing proof, one atomic terminal projection, and a mechanically validated recursion sentinel. The non-UI design verdict is PROCEED with no unresolved decisions; plan and implementation remain untouched pending FO advancement.

<!-- section:plan-stage-report -->
## Stage Report: plan

- DONE: Mechanically import all 12 design constraints and D1-D5 anchors, revalidate shape/design assumptions, and produce canonical ROADMAP/PRODUCT/ARCHITECTURE actions plus schema/fmodel/recovery lens coverage without silently changing selected contract.
  Readiness, handoff, D-reference, and count-preserving import checks pass. The plan makes the approved ownership, intent, receipt-first discovery, and atomic bundle seams executable with no open decision or appetite blocker.
- DONE: Emit executable medium-batch plan with bounded atomic waves, explicit owned paths/dependencies, per-task skills, and persisted TDD ledger contracts requiring observable RED before GREEN for landing proof, transaction recovery, recursion sentinel, compatibility, PR #40/#41 dogfood.
  Five serial waves carry distinct skill lists and focused RED/GREEN commands; `tdd-ledger.txt` and `tdd-ledger.jsonl` validate all five task records.
- DONE: Run plan self-review, fresh seven-factor cross-review, TDD-ledger/handoff/invariant validation, and record plan stage report/metrics; do not implement code/tests during plan.
  Final verdict is PROCEED after correcting skill-authoring coverage and converting recovery assumptions into observable CAS-producer, receipt-discovery, and exact bundle call-count contracts; `skill-coverage: PASS`.
- BOUNDARY: No implementation code, product tests, workflow state, canonical docs, or external PR/issue state changed. Only plan-stage artifacts, ledger evidence, and this report were written.

### Summary

Planned native post-merge closeout as five ordered TDD waves: landing proof, durable receipt/intent schema, atomic direct bundle, optional-PR/sentinel recovery with frozen PR #40/#41 dogfood, and compatibility/docs closeout.

### Metrics

- status: passed
- duration_minutes: 60
- iteration_count: 5
- task_count: 5
- verification_spec_count: 8
- imported_design_constraints_count: 12
- reviewer_verdict: PROCEED
<!-- /section:plan-stage-report -->

<!-- section:execute-stage-report -->
## Stage Report: execute

- DONE: Execute T1-T5 in serial waves with delegated ownership, observable RED before GREEN for every code-bearing task, pathspec-locked commits, and independent spec/quality review before each wave closed.
  Eight implementation/docs commits cover landing proof, receipt/intent contracts, atomic direct projection, sentinel-first optional PR recovery with PR #40/#41 dogfood, and operator documentation.
- DONE: Run the complete DC-1..DC-8 acceptance matrix plus optional-PR recovery, ledger, syntax, Python compile, ShellCheck, diff hygiene, and a no-network operator command UAT.
  Landing is 89/89; reconciler 160/160; PR40/41 103/103; optional PR 141/141; debrief/C15 and the seven-command compatibility chain pass; all ancillary gates exit 0.
- DONE: Fresh Science Officer execute reverse-audit checks plan-task attribution, stub acknowledgements, deviation capture, evidence completeness, and Hand-off to Verify accuracy before the artifact commit.
  The first pass returned an artifact-only VETO; after reattributing `42f8e06` to a disclosed cross-wave T2 reopen and recording the unused writing-skills methodology, re-review returned PROCEED with no implementation blocker.
- DONE: Re-enter Execute for Verify feedback cycle 1 and repair B1-B5 plus W1 through three owned-path TDD lanes, with independent reviews overlapped against later disjoint execution.
  Commits `3ee8f21`, `490a294`, and `fb6f4aa` make merged envelopes fail closed, assign one projection owner, preserve the full tracked entity tree, validate canonical D1/D4 receipt semantics, survive post-commit signals, and keep PR/direct ROADMAP parity. Fresh re-review APPROVED; receipt 81/81, bundle 69/69 on both shells, optional 176/176, default 195/195, direct 197/197, and PR40/41 138/138 pass. W2 remains deferred hardening.
- DONE: Close the aggregate C14 compatibility gap without rewriting the feedback transition history.
  Commit `b5fa535` sanctions only subject/state/body-bound FO feedback receipts; focused C14 is 31/31 and full C1-C15 exits 0 after an independent APPROVED review.
- DONE: Re-enter Execute for Verify feedback cycle 2 and close R2-B1-R2-B4 without taking the deferred W2 or receipt-scan performance warnings into acceptance scope.
  Commits `b6cd023`, `91402c7`, `110bc09`, and `85d6dff` require native proof before active legacy closeout, bind authoritative squash source commits through direct/optional/replay paths, restrict ROADMAP identity to cell zero, and guard root-parent speculation. Independent reviews APPROVED; resolver 94/94 both shells, receipt 85/85, bundle 78/78 both shells, integration 23/23, default 198/198, direct 200/200, optional 179/179, and PR40/41 141/141 pass.
- BOUNDARY: No external PR, push, merge, deployment, issue update, archive, or verify-stage advance occurred. Non-UI render fidelity is N/A.

### Summary

Implemented proof-backed native post-merge closeout with one atomic direct bundle or one deterministic optional closeout PR, receipt-first crash recovery, authoritative squash-source validation, mechanical recursion prevention, truthful operator docs, and hermetic regression coverage.

### Metrics

- status: passed
- duration_minutes: 505
- iteration_count: 18 implementation/review repair loops
- task_count: 13
- commit_count: 16 implementation/docs commits
- reviewer_verdict: APPROVED after both feedback cycles received independent re-review
<!-- /section:execute-stage-report -->

<!-- section:verify-stage-report -->
## Stage Report: verify

- DONE: Independently boot the exact execute snapshot, extract the schema/context manifests, validate the persisted TDD ledger, and rerun the scoped landing, receipt, transaction, reconciler, compatibility, and static evidence without trusting execute self-attestation.
  The verifier reproduced 951 counted focused assertions plus the exact compatibility chain; C14/C15, syntax, Python compile, ShellCheck, and diff hygiene are green.
- DONE: Run the mandatory read-only panel for general, silent-failure, testing, maintainability, security, schema/domain, and adversarial coverage, spot-check every citation, and cross-review the bounded failed artifact.
  Two parallel panels found five unique blockers and two warnings; the fresh process cross-review returned PROCEED for the honest failed artifact and execute route, not for the implementation.
- FAILED: Required integrated claims B1-B5 are NOT VERIFIED, so Verify VETOs and routes back to Execute without a proceed receipt or state advance.
  The blockers are incomplete-envelope legacy fallback, duplicate startup terminalization, loss of the full archived entity evidence tree, underconstrained receipt semantics, and post-commit signal rollback corruption; W1 accompanies the execute repair and W2 remains explicit hardening risk.
- DONE: Re-enter Verify at valid entry `5523916`, preserve the round-1 record, and independently confirm feedback-cycle repairs B2/B3/B5/W1 with 1,286 focused assertions plus full C1-C15 green.
  The round-2 pinned implementation snapshot is `d45d176..c0494e5`; green suites do not override uncovered integration paths.
- FAILED: Round 2 VETOs on four required claims and routes back to Execute.
  R2-B1 allows active legacy done/PASSED archive before native proof; R2-B2 permits self-rehashed squash source-patch forgery; R2-B3 accepts ROADMAP identity outside the first cell; R2-B4 can crash a valid young-repo squash during speculative rebase analysis. Same-user path-swap TOCTOU and O(E×R) receipt scanning remain non-blocking warnings.

### Summary

Verification preserves both VETO rounds. Cycle 1 repairs B2/B3/B5/W1, but round 2 rejects the implementation because four uncovered proof, projection, and topology paths still violate the native closeout contract. The authoritative history and current four required `NOT VERIFIED` claims remain in [verify.md](verify.md).

### Metrics

- status: failed
- duration_minutes: 26 across two rounds
- iteration_count: 2
- blocking_findings_count: 4 current (5 historical)
- warning_findings_count: 2
- reviewer_verdict: VETO round 2; route execute
<!-- /section:verify-stage-report -->

### Feedback Cycles

- cycle: 1
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-15T11:03:07Z
  verify_artifact: verify.md@ae56c20
  required_fixes: B1 incomplete-envelope legacy fallback; B2 duplicate startup terminalization; B3 full entity-tree archive preservation; B4 canonical landing/output receipt semantics; B5 post-commit signal recovery; W1 pull-request ROADMAP title/table validation parity
  deferred_hardening: W2 same-user path-swap TOCTOU remains explicit non-acceptance follow-up
- cycle: 2
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-15T12:41:35Z
  verify_artifact: verify.md@a55629d
  required_fixes: R2-B1 legacy done/PASSED bypass before native proof; R2-B2 squash source patch-id forgery; R2-B3 ROADMAP identity-column validation; R2-B4 young-repo root-parent crash
  deferred_hardening: W2 same-user path-swap TOCTOU and O(E x R) receipt scanning remain non-acceptance follow-ups

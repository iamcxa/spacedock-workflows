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
- DONE: Re-enter Execute for Verify feedback cycle 3 and close only R3-B1 while deferring W2/W3/W4.
  Commits `54a4a9a` and `8d1ac64` boundedly reacquire authoritative GitHub PR source objects in true main-only and post-prune replay states, bind repo/PR/provider OIDs, preserve checkout/remotes, and make temporary-ref creation collision/signal safe. Focused R3 is 107/107 on Bash 3.2 and 5.3; compact R2 regressions are 13/13 and 23/23; the same reviewer APPROVED all three prior findings as closed.
- DONE: Re-enter Execute for Verify feedback cycle 4 and close only R4-B1 plus directly coupled R4-W1 while deferring W2/W3/W4.
  Commit `eba76c1` binds implementation and closeout PR view/list/create/ready operations plus validated receipt identity to the authoritative provider repository from any caller CWD. Final RED was 19/10; R4 is 29/29 and R3 is 107/107 on both shells; R2 is 13/13 + 23/23, default is 198/198, and fresh spec/quality reviews APPROVED.
- DONE: Re-enter Execute for Verify feedback cycle 5 and close only R5-B1 while preserving R2-R4 and deferring W2/W3/W4.
  Commits `0fdbe25` and `743f1af` map provider list/create/ready failures to one stable checkpoint verdict, resume exact local/remote state without duplicates, and prove the precise base-plus-receipt checkpoint tree. Final RED was 121/20; R5 is 141/141 on Bash 3.2 and 5.3, R4 is 29/29 both shells, isolated R3 is 107/107, R2 is 13/13 + 23/23, default is 198/198, and independent review APPROVED after one test-quality repair.
- DONE: Re-enter Execute for Verify feedback cycle 6 and close only R6-B1 plus directly coupled R6-W1 while preserving R2-R5 and deferring W2/W3/W4.
  Commit `0a47e50` counts actual seed/terminal push invocations, skips an already exact remote seed, fails closed on divergent or uninspectable refs, and composes internally owned bundle cleanup with source-object signal cleanup. Final RED was 235/44; R6 is 279/279 both shells, R4 is 29/29 both, isolated R3 is 107/107, R2 is 13/13 + 23/23, default is 198/198, and fresh spec/quality reviews APPROVED.
- DONE: Add the Cycle 7 deterministic inspection-to-push race regression while production is frozen.
  The local-bare wrapper inserts an ancestor-valued competitor immediately before the real seed push; the causal RED was 14/5 and failed exactly on competitor overwrite, post-race provider creation, and the missing expected-absence lease/full-ref destination.
- DONE: Close only R7-B1 with atomic expected-absence seed publication while preserving exact retry and terminal-publication semantics.
  Commit `e3adebe` uses a create-only full-ref lease, preserves the competing remote ref plus exact local checkpoint bytes on rejection, emits stable `PROMPT_CAPTAIN / closeout-checkpoint-conflict / closeout_pr_prepared`, publishes a missing seed once, skips an exact existing OID, and leaves the terminal OID lease unchanged.
- DONE: Preserve the Cycle 6 recovery envelope and complete Cycle 7 review/report gates without widening into W2/W3/W4.
  R7 is 19/19, R6 is 279/279, R4 is 29/29, isolated R3 is 107/107, R2 is 13/13 + 23/23, and default is 198/198 on both Bash 3.2 and 5.3; independent spec/quality reviews APPROVED, the pinned ledger/Spacedock checks pass, and the full compatibility chain plus C1-C15 exit 0.
- BOUNDARY: No external PR, push, merge, deployment, issue update, archive, or verify-stage advance occurred. Non-UI render fidelity is N/A.

### Summary

Implemented proof-backed native post-merge closeout with one atomic direct bundle or one deterministic optional closeout PR, atomic expected-absence seed publication, receipt-first crash recovery, bounded authoritative provider/object binding, mechanical recursion prevention, truthful operator docs, and hermetic regression coverage.

### Metrics

- status: passed
- duration_minutes: 809
- iteration_count: 25 implementation/review repair loops
- task_count: 18
- commit_count: 23 implementation/docs/test commits
- reviewer_verdict: APPROVED after all seven feedback cycles received independent re-review
<!-- /section:execute-stage-report -->

<!-- section:verify-stage-report -->
## Stage Report: verify

- DONE: Pin round 8 to implementation/test `e3adebe` at metadata-only `15ec239`. Current tests with pre-fix
  production reproduce 14/19 RED on both Bash versions; current production is 19/19 GREEN on both.
- DONE: Verify single-endpoint expected-absence CAS, checkpoint/provider preservation, terminal lease, R6 279/279
  both shells, R4 29/29 both, R3 107/107, R2 13/13 + 23/23, default 198/198, static/contracts, and pinned status.
- FAILED: Two panels and an independent local Git probe find R8-B1. With two pushurls, endpoint A accepts the seed
  before endpoint B rejects its competitor; aggregate exit 1 therefore follows partial remote mutation.
- GATE: Round 8 returns only R8-B1 and its coupled multi-pushurl regression to execute. Verdict is
  FAILED/PROMPT_CAPTAIN; no implementation, receipt/status/Review dispatch/external push/PR/merge/archive/todo/network mutation occurred.

### Summary

Round 8 closes the prior single-endpoint race, but a named remote can fan out and fail after partial publication.
The bounded failed artifact and Captain-gated VETO are recorded in [verify.md](verify.md).

### Metrics

- status: failed
- duration_minutes: 101 across eight verify rounds
- iteration_count: 8
- blocking_findings_count: 1 current
- warning_findings_count: 4
- claim_records: required VERIFIED=7 NOT VERIFIED=1 INCONCLUSIVE=0
- reviewer_verdict: VETO round 8; Captain Verify gate FAIL/PROMPT_CAPTAIN
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
- cycle: 3
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-15T13:59:00Z
  verify_artifact: verify.md@6ca8236
  required_fixes: R3-B1 bounded authoritative implementation-PR source-object acquisition for main-only first closeout and cleanup/GC replay
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
- cycle: 4
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-15T15:10:04Z
  verify_artifact: verify.md@a217804
  required_fixes: R4-B1 authoritative repository binding for receipt-first and optional closeout-PR GitHub operations with foreign-CWD non-dry-run coverage
  deferred_hardening: R4-W1 fake-gh repository-binding assertions accompany the blocker; W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
- cycle: 5
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-15T15:56:29Z
  verify_artifact: verify.md@39dd0b1
  required_fixes: R5-B1 stable provider list/create/ready failure routing plus resumable partial-state recovery without duplicate commits, PRs, or remote heads
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
- cycle: 6
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-15T16:44:42Z
  verify_artifact: verify.md@4e2e91a
  required_fixes: R6-B1 eliminate duplicate seed push invocation on create-before retry with direct push-count regression; R6-W1 bound provider-failure bundle_root cleanup
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
- cycle: 7
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-15T17:50:03Z
  verify_artifact: verify.md@db921e0
  required_fixes: R7-B1 atomic expected-absence seed publication with inspection-to-push interleaving regression
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling

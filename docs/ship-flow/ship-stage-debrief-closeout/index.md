---
id: ""
title: "Make debrief a native post-merge ship closeout"
status: plan
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
worktree: .worktrees/spacedock-ensign-ship-stage-debrief-closeout
---

<!-- section:stage-artifact-links -->
| Stage | File |
| --- | --- |
| shape | [shape.md](shape.md) |
| design | [design.md](design.md) |
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

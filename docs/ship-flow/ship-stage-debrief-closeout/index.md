---
id: ""
title: "Make debrief a native post-merge ship closeout"
status: ship
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

- DONE: Execute T1-T5 and feedback cycles 1-11 deliver proof-backed native post-merge closeout. Cycle 11 accepts the unique in-window awaiting predecessor on mature main, exact-resolves `refs/heads/*` under a same-name tag, binds landed recovery to provider `headRefOid` plus predecessor ancestry, and signal-owns all validator outputs (`2c02bae`).
- DONE: Causal Cycle 11 RED evidence reached validator seams 38/12, validator-root creation 62/4, and colliding-tag history 9/2; GREEN is R11 91/91, R10 120/120, and default 198/198 on Bash 3.2 and 5.3, with no parallel signal-heavy suite treated as authoritative.
- DONE: Bash syntax, ShellCheck, Python compile, TDD ledger (`status=pass records=5`), diff hygiene, and full invariants C1-C15 pass; independent final specification/recovery review is PASS and pinned status remains `execute` for FO-controlled advancement.
- BOUNDARY: No external PR, push, merge, deployment, issue update, archive, RoboRev invocation, or verify-stage advance occurred. Non-UI render fidelity is N/A.

### Summary

Implemented one fail-closed closeout authority chain from authoritative provider endpoint through leased publication, exact terminal predecessor ancestry, and signal-owned validation. Execute is complete and the First Officer may route Verify.

### Metrics

- status: passed
- duration_minutes: 2105
- iteration_count: 36 implementation/review repair loops
- task_count: 22
- commit_count: 27 implementation/docs/test commits
- reviewer_verdict: PASS after all eleven feedback cycles received independent re-review
<!-- /section:execute-stage-report -->

<!-- section:verify-stage-report -->
## Stage Report: verify

- DONE: Round 13 (BOUNDED delta+regression) proves R12-B1 (all six deterministic-head sites incl. both
  send-pack SRC), R12-B2, and R12-W1 closed, GREEN on both Bash 3.2 and 5.3 — closing the fold-in's stated
  Bash-3.2 gap (R12 suite 29/29 + send-pack-src regression re-run on 3.2).
- DONE: Existing suite regression-green both shells: R11 91/91, R10 120/120, default 198/198; landing 94/94
  and receipt 92/92 also refreshed both shells; T5 compatibility bundle green. Static/hygiene (C1-C15,
  no-dangling, version-triple, shellcheck, bash -n, diff --check) and TDD ledger (`status=pass records=5`) pass.
- DONE: One fresh independent reviewer (`silent-failure-hunter`) dispatched against the exact delta diff:
  NO_FINDINGS. No new defect class found.
- GATE: Round 13 is PROCEED. Advance to Review. No implementation/test behavior beyond the reviewed delta,
  network, remote, PR, merge, archive, todo, or RoboRev state changed.

### Summary

Cycle 12's core fix plus FO-triaged fold-in close all three Round-12 findings uniformly, including the two
send-pack SRC sites the original review did not cite, and the fold-in's stated Bash-3.2 confirmation gap is
now closed. Full evidence, per-AC-1..7 citations, and the PROCEED verdict are in [verify.md](verify.md).

### Metrics

- status: passed
- duration_minutes: 35 for round 13
- iteration_count: 13
- blocking_findings_count: 0
- warning_findings_count: 0
- claim_records: required VERIFIED=5 NOT VERIFIED=0 INCONCLUSIVE=0
- reviewer_verdict: PROCEED round 13; independent silent-failure-hunter re-check corroborates delta closure
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
- cycle: 8
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-16T01:02:19Z
  verify_artifact: verify.md@aff77fb
  required_fixes: R8-B1 prevent multi-pushurl partial seed publication by enforcing one authoritative destination or one canonical verified URL, with a two-pushurl zero-endpoint-mutation regression
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
- cycle: 9
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-16T02:39:01Z
  verify_artifact: verify.md@bbe943f
  required_fixes: R9-B1 bind a non-reinterpretable leaf publication endpoint across nested remotes and URL rewrites; R9-B2 persist and validate provider-bound endpoint identity across retries and re-query provider head before ready/success; add coupled seed/terminal regressions
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
- cycle: 10
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-16T08:21:18Z
  verify_artifact: verify.md@13af3c3
  required_fixes: R10-B1 require endpoint-local fixture authorization and revalidate every loaded persisted endpoint against the authoritative provider before effects; R10-B2 predecessor-bind reused/landed terminal receipts and add actual transport, terminal-lease, legacy-hydration, and provider-refresh recovery regressions
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
- cycle: 11
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-16T14:47:45Z
  verify_artifact: verify.md@453c4f1
  required_fixes: R11-B1 accept a unique valid nearby awaiting predecessor on mature main while preserving bounded-failure semantics; R11-B2 require landed terminal bytes and any local deterministic ref to bind the authoritative provider headRefOid with ancestry proof; R11-B3 move every receipt/preflight validator temp into signal-owned cleanup and cover HUP/INT/QUIT/TERM residue behavior
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
- cycle: 12
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-16T16:58:26Z
  verify_artifact: verify.md@05c6c70
  required_fixes: R12-B1 resolve awaiting/OPEN/build deterministic heads exactly (fully-qualified refs/heads/ or verified OID) so a same-name tag can never be DWIM-selected; R12-B2 bind ancestry to the awaiting predecessor that is an actual ancestor of the provider terminal, not the newest commit carrying identical awaiting bytes; R12-W1 propagate ensure_owned_validator_root failure explicitly so an empty root cannot feed /validator.XXXXXX under suppressed errexit
  deferred_hardening: W2 same-user path-swap TOCTOU; W3 O(R+E) receipt scanning; W4 review-scope range tooling
  scope_boundary: Captain-set BOUNDED CONVERGENCE round. Execute fixes ONLY R12-B1/B2/W1 plus their focused regressions; no new hardening surface, no unrelated refactor. Verify re-review is DELTA+REGRESSION scoped only (prove B1/B2 closed on both shells, then run the existing green suite for regressions) and MUST NOT open a new adversarial-Git frontier (no fresh multi-endpoint/nested-remote/URL-rewrite/provider-drift class). Stop rule (Captain): verify PROCEED -> advance to Review/ship; a brand-new blocker CLASS that is not a B1/B2 regression is the non-convergence signal -> FO defers it to a tracked follow-up entity and ships on the green core; do NOT auto-route a Cycle 13.

## Stage Report: execute (cycle 12)

- DONE: R12-B1 closed. `resolve_exact_deterministic_commit()` added (verified 40-hex OID passes
  through as-is; a branch-name-shaped head resolves only via `refs/heads/<name>^{commit}`), used
  by `optional_terminal_head_matches` internally and mirrored at the four external bare-resolution
  sites (`scan_closeout_receipts` awaiting check, `ensure_initial_closeout_head`,
  `resolve_or_create_closeout_pr` fixture reuse, `build_optional_terminal_head`). A same-name tag
  with a different OID/tree is never DWIM-selected. Proven by
  `run_feedback_r12_b1_tag_dwim_case`, RED confirmed against the pre-fix reconciler via
  `git stash` (exit 1, `detail=existing terminal closeout head does not extend the durable
  awaiting predecessor`), GREEN 21/21 on Bash 3.2 and 5.3.
- DONE: R12-B2 closed. `recover_awaiting_closeout_predecessor` gained a `terminal_ref` parameter
  and now prefers the first ancestor-of-terminal candidate (`git merge-base --is-ancestor`) among
  commits carrying identical awaiting bytes, falling back to the legacy newest-carrier pick only
  when no candidate is an ancestor at all (preserving existing bounded-failure semantics for
  genuinely-ambiguous / no-valid-ancestor cases — verified against the existing R11
  provider-ancestry regression, 91/91). A legal A/B/T/M recovery proceeds. Proven by
  `run_feedback_r12_b2_ancestry_case` (one `--allow-empty` main commit reproduces the
  concurrent-main-movement carrier B), RED confirmed via `git stash` (exit 1, `detail=landed
  closeout provider head does not descend from its durable awaiting checkpoint`), GREEN 21/21 on
  both shells.
- DONE: R12-W1 closed + gate green. `ensure_owned_validator_root` now calls
  `reject_input closeout-checkpoint-conflict` (unconditional `exit 2`, independent of any
  `set -e` suppression in the calling context) instead of a bare `return 1`, covering all 6 call
  sites uniformly. Proven by `run_feedback_r12_w1_validator_root_case` (PATH-shadowed `mkdir`),
  RED confirmed via `git stash` (exit 1, no `reason=` line at all), GREEN 21/21 on both shells.
  Full local gate: R12 21/21, R11 91/91, R10 120/120, default 198/198 — all dual-shell (Bash 3.2
  and 5.3); `check-invariants.sh` C1-C15 exit 0; `check-no-dangling.sh` PASS;
  `check-version-triple.sh` PASS; `bash -n`/`shellcheck -s bash`/`git diff --check` all clean; TDD
  ledger unchanged (`status=pass records=5`, matching prior-cycle convention). No scope growth
  beyond B1/B2/W1 — see execute.md "Deferred / out-of-scope observations" for one uncited,
  out-of-scope bare-refspec DWIM instance in the optional-PR push-destination path, left for FO
  triage.

### Summary

Cycle 12 closed the two Round-12 BLOCKING findings and the coupled WARNING with the smallest
correct fix for each: exact `refs/heads/` resolution (never DWIM to a same-name tag), an
ancestor-of-terminal-first predecessor scan with a legacy fallback that preserves prior
bounded-failure behavior, and an unconditional fail-closed validator-root guard. All three RED
before fix (verified against the pre-fix code via git stash) and GREEN after, with the full
existing regression suite (R10/R11/default) unaffected on both shells.

## Stage Report: ship

- DONE: PR #56 created (base `main`, head `spacedock-ensign/ship-stage-debrief-closeout`) —
  https://github.com/iamcxa/spacedock-workflows/pull/56. Body describes the closeout feature
  (landing envelope, `--closeout-mode direct|pull-request`, recursion sentinel, AC-1..AC-7), cites
  verify Round 13 PROCEED evidence, and references the merged C14 prerequisite #54 (`79df977`,
  adopted via merge commit `5767488`). Branch confirmed 0 behind / 97 ahead of `origin/main`,
  `mergeable: MERGEABLE`.
- DONE: Doc-impact gate satisfied. Ran `bin/doc-impact-gate.sh` locally against
  `merge-base(origin/main, HEAD)...HEAD`: `PASS reference-schema-readme` and
  `PASS checker-source-map` — both mechanically-triggered couplings already have their coupled doc
  (`references/doc-sync-context.md`, `plugins/ship-flow/README.md`) touched in-diff (from T5). No
  new `bin/` checker was added (the reconciler is an existing, heavily-extended file with an
  existing Source-Map row), so no new row was required. Declared in the PR body.
- DONE: Canonical docs synced per `plan.md`'s Canonical Doc Actions, via `lib/patch-map.sh` CAS
  (read-first `--if-hash`, no freehand edits):
  `ROADMAP.md` — removed the stale `Now` row (still said stage `shape`) and appended exactly one
  `Shipped` row (`ship-stage-debrief-closeout | ... | 2026-07-17 (PR #56)`).
  `PRODUCT.md` — appended one `capabilities` row for the native post-merge closeout.
  `ARCHITECTURE.md` — replaced `components` (prose + mermaid: new `closeoutlib` component and
  relations, extended references list), appended one `constraints` bullet citing D1-D5, and
  appended one `decisions` row summarizing D1-D5. All three `patch-map.sh` calls exited 0; local
  `check-invariants.sh` (exit 0, all C1-C15 OK), `check-no-dangling.sh` (PASS), and
  `check-version-triple.sh` (PASS, version unchanged at 0.9.0) all re-verified after the edits.
- DONE: Release consideration recorded. This PR does not bump the plugin version (stays 0.9.0,
  `check-version-triple.sh` PASS) — matches this repo's established convention of a separate later
  `chore(ship-flow): release X.Y.Z` PR (precedent: #19, #17) rather than bundling a version bump
  into the feature PR. Given the size of this slice (native post-merge closeout is a new pipeline
  capability, not a patch), a minor bump (0.9.0 → 0.10.0) is a reasonable candidate for that
  follow-up release PR; left for the captain to schedule.
- FINDING: PR #56 CI shows `doc_impact` PASS and `GitGuardian Security Checks` PASS, but
  `invariants` FAILS. Root-caused (not a regression from this stage's changes — this stage touched
  only `ROADMAP.md`/`PRODUCT.md`/`ARCHITECTURE.md`): `lib/__tests__/test-merged-pr-closeout-reconciler.sh`'s
  `setup_repo()` runs `git init -q "$repo"` without pinning the initial branch name, unlike sibling
  fixtures in the same suite (`test-apply-closeout-bundle.sh` / `test-closeout-receipt.sh` use
  `git init -q -b main`; `test-landing-envelope-resolver.sh` follows with `git branch -M main`).
  The local dev sandbox where all 13 verify rounds ran has `init.defaultbranch=main` set
  system-wide (macOS Xcode git); `ubuntu-latest` (GitHub-hosted CI) does not, so the first
  `git checkout -q main` reached in the default run (`prepare_full_d1_repo`, via
  `run_missing_landing_field_matrix`) fails with `pathspec 'main' did not match any file(s)`, and
  `set -euo pipefail` aborts the rest of that one file — silently skipping most of its ~30
  remaining test-case functions on real CI, though every other `test-*.sh` in the same run passed.
  This means large parts of this feature's claimed local-GREEN coverage have never been proven on
  a portable CI runner. Posted as a detailed PR comment
  (https://github.com/iamcxa/spacedock-workflows/pull/56#issuecomment-5001700139); NOT fixed here —
  out of this stage's scope (PR + canonical docs only). Recommend the FO route a narrowly-scoped
  fix (pin the branch name in `setup_repo()`) before merge.
- BOUNDARY (HARD STOP honored): PR #56 was NOT merged (no `gh pr merge` run). Entity status was NOT
  advanced to `done`. `merged-pr-closeout-reconciler.sh` / the closeout / the `done` merge hook was
  NOT run. No rebase, no force-push. PR #54 and no other entity were touched. Entity remains at
  `status: ship` with PR #56 open.

### Summary

Opened PR #56 (base `main`) describing the native post-merge closeout feature, satisfied the
doc-impact gate mechanically (both triggered couplings already covered in-diff), and synced
ROADMAP/PRODUCT/ARCHITECTURE per `plan.md`'s Canonical Doc Actions via the CAS-mediated
`patch-map.sh` (no freehand edits). Discovered and root-caused a pre-existing, CI-only test-fixture
bug in `test-merged-pr-closeout-reconciler.sh` (unpinned `git init` default branch) that silently
skips most of that file's cases on GitHub Actions despite 13 rounds of local GREEN — documented on
the PR and here, left unfixed as out of ship-stage scope. Did not merge, did not advance to `done`,
did not run the closeout reconciler; entity stays at `status: ship` with PR #56 open for captain
review.

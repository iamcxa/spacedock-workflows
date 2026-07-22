---
title: Make stage circuits attempt-scoped and recoverable
status: plan
source: SO/EM narrow verdict on shape-confirm-instance-awareness plan recovery
started: 2026-07-22T02:05:16Z
completed:
verdict:
score: 0.95
worktree: .worktrees/spacedock-ensign-attempt-scoped-stage-circuits
issue:
pr:
domain: schema
design_required: true
contract_decision_required: true
affects_ui: false
---

Ship-Flow's plan circuit breaker measures an accumulated stage clock but has no durable attempt identity or fresh-versus-resume semantics. After a truthful partial receipt, a newly dispatched continuation inherits an already-expired duration and can never legitimately pass, producing deterministic recovery livelock and forcing agents to infer lifecycle from prose.

## Acceptance criteria

- **AC-1 (value, cli):** After a partial attempt, one fresh continuation can complete within its own 20-minute budget and publish a truthful passed receipt; resume/replay cannot reset that same attempt's budget.
- **AC-2 (mechanism, cli):** Dispatch and receipts carry durable `attempt_id`, `attempt_started_at`, terminal state, and lease binding; current-attempt duration is distinct from monotonic cumulative stage duration.
- **AC-3 (value, cli):** Crash recovery and receipt replay are idempotent: no duplicate attempt, no double-counted duration, and no ambiguous unclosed attempt.
- **AC-4 (mechanism, cli):** A bounded attempt-count or cumulative-duration escalation prevents infinite retry and emits an explicit routeable outcome.
- **AC-5 (value, cli):** The existing #21 partial receipts remain auditable, and one post-landing attempt-scoped revalidation can unblock its unchanged technical plan without waiving the breaker.

## Scope

In: attempt lifecycle schema/prose, FO dispatch envelope/lease integration, receipt publication and validators, recovery/idempotency tests, and bounded escalation.

Out: redesigning #21's allocator plan, changing product code in its preserved diff, generic distributed scheduling, split-root expansion unrelated to attempt identity, or silently treating partial as passed.

## Stage Report: shape

- DONE: Produce a small-batch Shape Up proposal whose end value is that a post-partial fresh attempt can complete under its own budget without weakening resume/replay accounting or requiring a general dispatch/state rewrite.
  `shape.md` defines two plan/execute vertical slices totaling 2.3/3 days, with paired fresh, resume/replay, bounded-route, and #21-preservation dogfood checks.
- DONE: Ground the proposal in fresh L0 code research, current #21 partial-receipt evidence, canonical docs, the captain articulation trail, and a bounded architecture/contract impact with explicit exclusions.
  Fresh L0 cites the 20-minute breaker, exact completion lease/receipt seam, schema gap, 32/61-minute #21 receipts, debrief crash warnings, canonical skips, and schema-domain architecture intent.
- DONE: Complete appetite-fit, critical-assumption verification, PM-skill receipts, domain/contract routing, and independent cross-review; return a captain-facing Layer 1 gate with a truthful Stage Report, without approving or advancing it.
  Appetite fit is 77%; PM delegates record valid unavailable/inline fallbacks; schema validation passed; review warnings were incorporated, and the captain's W1–W4 approval and Bet are recorded verbatim.

### Summary

Shaped a two-slice prerequisite that makes plan/execute attempts explicit,
lease-bound, replay-safe, and bounded without changing #21 or introducing a
scheduler. The artifact stops at the captain gate: frontmatter remains `shape`,
the captain approved W1–W4 and supplied the Bet, and no stage transition,
dispatch, worktree, or product-code change was made.

## Captain Bet (gate approval 2026-07-22)

**Bet substance — captain verbatim**

> 我希望在 ship 後下一次 dogfood 自我實作時就會立即看到更 agnet-native 的行為，如果沒有則代表方法論不對。

**Approval token — captain verbatim**

> 同意：這個 part 的「更 agent-native」限定為 W1–W4；approve

## Stage Report: design

- DONE: Resolve CD-1 through CD-4 into captain-decision-anchored design constraints that preserve legacy receipt bytes, FO-only attempt and timing authority, crash-safe append-only terminal semantics, and bounded no-dispatch route-out.
  `design.md` records D1-D4, freezes `completion-v1`, fixes plan/execute identity and clock ownership, defines entity+stage exclusion across sibling worktrees, and specifies exact WAL, returned-bundle, terminal-history, replay, and route-out contracts.
- DONE: Produce schema/contract design output plus a complete Hand-off to Plan that remains limited to plan and execute and keeps #21's technical plan and 32/61-minute receipts unchanged.
  The schema section covers authority/projection layers, additive migration, rebuild, and plan/execute report fields; the hand-off has no open decisions and makes #21 byte-preservation plus one typed fresh revalidation an explicit D4 constraint.
- DONE: Complete the required readiness and adversarial review evidence with no unresolved decisions; route narrow if the design needs generic scheduling, unrelated-stage migration, cross-workflow coordination, or exceeds the three-day appetite.
  Schema and fmodel readiness are PASS, the final fresh seven-factor review says PROCEED, D-reference and hand-off validators pass, and the design explicitly excludes every narrow/return trigger.

### Summary

Designed a plan/execute-only attempt circuit with per-attempt ref and clock
authority, exact crash-recoverable return evidence, one bounded fresh
continuation, and pre-dispatch route-out. The final review is PASS with no open
decisions; the First Officer still owns stage advancement.

## Stage Report: plan

⚠️ INCOMPLETE — this plan attempt crossed the 21-minute circuit while fresh
semantic review was still running. The delayed review's one RED-harness veto is
repaired and later APPROVED, but the expired receipt remains partial; FO must
run one bounded fresh receipt/gate-repair continuation before stage advance.

- DONE: Import every D1-D4 hand-off constraint mechanically and produce runnable TDD tasks for exact completion-v1 preservation, attempt identity/timing, crash/replay transitions, bounded route-out, and #21 byte preservation.
  `plan.md` imports 10/10 design rows and defines W0 RED-first tests plus four serial implementation waves; the persisted ledger validates five records.
- DONE: Produce dependency-safe plan/execute-only task waves with exact file paths, RED/GREEN commands, verification evidence, worker skills, and reviewer questions; do not expand into generic scheduling, unrelated stages, cross-workflow coordination, or #21 product redesign.
  W0→W4 owns disjoint explicit paths, four skills lists, runnable DC-1–DC-4 procedures, a 15-path M boundary, and the exact no-expansion constraints.
- FAILED: Pass the TDD ledger, design-readiness, hand-off schema, D-reference, and design-import validators plus fresh adversarial cross-review within the attempt circuit; leave no open decisions or placeholders, and return to narrow if the full fault matrix cannot fit the captain's hard three-day appetite.
  Ledger, readiness, hand-off, D-reference, C4/C8, placeholder, C15, and diff gates pass. The delayed reviewer returned APPROVED after one narrow RED-harness repair, but only after the attempt circuit expired, so the receipt cannot claim passage.

### Summary

Published a mechanically valid, RED-first five-task plan with independently
observable RED suites, exact fault ordering, and pinned #21 evidence. Late
review evidence is durable, but this expired attempt returns partial to the
First Officer without stage advancement.

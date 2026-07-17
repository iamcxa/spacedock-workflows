# Issue-anchor scope-drift guard (route-back re-anchor) — Shape

## Problem

The only real route-back into shape is a captain re-invoking /shape <entity-id> on an entity already carrying design.md/plan.md (no stage declares feedback-to:shape; design VETO loops within design). On re-entry ship-shape re-reads the entity's own accumulated artifacts, never the immutable original tracker issue, so scope drifts from the original acceptance criteria across rounds (issue #49 case study: a prerequisite re-shaped ~4 times, 2+ weeks lost, broke a release pipeline).

## Acceptance Outcome

When the captain re-shapes an entity that already has later-stage artifacts, ship-shape first re-reads the original GitHub issue via the entity issue: field and shows a source-diff — is current scope still within the original asks, is the original goal still unmet — so drift is caught before re-shaping perpetuates it; an entity with no issue: field is told so and asked to confirm scope manually, never given a fake anchor.

<!-- section:pm-skill-receipts -->
```yaml
pm_skill_receipts:
  stage: ship-shape
  mode: mode-a
  appetite: small-batch
  compose_guard: passed
  receipts:
    - phase: intake-problem
      delegate: problem-framing-canvas
      required: true
      status: unavailable
      evidence: ""
      fallback: inline problem-framing (JTBD lens applied by main agent)
      rationale: skill not installed in this environment
    - phase: scope-decompose
      delegate: opportunity-solution-tree
      required: true
      status: unavailable
      evidence: ""
      fallback: inline vertical-slice decompose via captain Q-loop
      rationale: skill not installed in this environment
    - phase: assumption-extract
      delegate: pol-probe-advisor
      required: true
      status: unavailable
      evidence: ""
      fallback: 'inline POL probe: critical-assumption filter applied by main agent'
      rationale: skill not installed; small-batch so not mandatory
    - phase: acceptance-outcome
      delegate: press-release
      required: true
      status: unavailable
      evidence: ""
      fallback: inline user-observable outcome phrasing
      rationale: skill not installed in this environment
```
<!-- /section:pm-skill-receipts -->

## Appetite

small-batch (2-3 days)

## Children



## Assumptions

- **A1 (critical, 90%)** — The only real route-back into shape is a captain
  re-invoking `/shape <entity-id>` on an entity already carrying later-stage
  artifacts; no stage declares `feedback-to: shape`, and ship-shape's Intake
  table is the attach point. _Verified by: skill-source-read (L0) —
  workflow-template.yaml declares feedback-to only on verify (→execute);
  ship-design VETO loops within design; ship-shape Intake table lines 49-57._
- **A2 (critical, 88%)** — The original issue is fetchable at re-shape time
  because ship-shape runs in the MAIN FO context (README: shape is FO-direct,
  not via ensign), so `gh issue view` + the entity `issue:` field suffice and
  the "subagents cannot call MCP" limit does not bite. _Verified by:
  skill-source-read — docs/ship-flow/README.md shape stage._
- **A3 (important, 80%)** — Most drift-prone entities carry an `issue:` field
  (`tracker: gh|linear`); free-text-origin entities are the minority and get
  the surface-to-captain exception. _Verified by: codebase-grep —
  entity-body-schema.yaml lines 40-41._

## Rabbit Holes

- issue-anchor-guard-memory-fallback
- reverse-recovery-audit-dangling-path
- issue-anchor-guard-remaining-triggers

## Deletes (rejected alternatives)

- **Mirror reverse-recovery-audit.md as unenforced prose (no Hook, no test)** —
  the stated analog is itself dangling and untested; ship this guard wired +
  pinned by a shell test instead, so its AC is enforced not just asserted.
- **Introduce new SO/EM route values `re-anchor`/`split`** (per issue #49 text) —
  the real existing vocabulary is `proceed/narrow/return/block/costly_no`; adding
  values changes the science-officer-em.md contract + its tests. Reconcile onto
  existing vocab (`re-anchor` → `return`) instead.
- **Implement all three trigger points this round** — small-batch proves the
  wedge first; cycle-3 lives in a different repo (spacedock core) and
  child-creation has no single chokepoint. Deferred to rabbit-holes.

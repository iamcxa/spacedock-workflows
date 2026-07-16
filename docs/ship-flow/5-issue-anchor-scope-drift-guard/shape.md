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

(fill in at shape stage)

## Rabbit Holes

- issue-anchor-guard-memory-fallback
- reverse-recovery-audit-dangling-path
- issue-anchor-guard-remaining-triggers

## Deletes

(fill in from deleted_from_shape)

# Ship-flow core: the human review surface is the shape/spec, not plan.md — Shape

## Problem

Ship-flow's review-surface discipline — the human captain reviews the shape/spec (what & why), never plan.md/execute.md — is lived practice (it drove the #49 build) but is not written into the plugin core. Because it is uncodified, an FO can offer the captain a plan.md review — a fake review that burns captain attention and invites rubber-stamping of agent framing — and a future refactor can silently erode the shape-only-gate boundary with nothing to catch it.

## Acceptance Outcome

The captain gets a durable, discoverable rule in ship-flow core: the human review surface is the shape/spec (and design.md when its conditional gate fires); plan.md/execute.md are agent-facing and are never offered for human review; after the shape gate the FO drives plan->execute->verify autonomously, stopping only for a direction-confirm or UAT, and instead confirms spec content with the captain in plain language. If that rule text regresses, a shell check (C16) fails.

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
      fallback: 'Inline problem framing: gap = review-surface rule uncodified in core; who = the captain, whose attention is burned by fake plan.md reviews; why now = the #49 plan.md-review incident (debrief 2026-07-17-01) demonstrated the silent erosion.'
      rationale: problem-framing-canvas skill not installed in this environment; problem framed inline in the shape Problem statement.
    - phase: scope-decompose
      delegate: opportunity-solution-tree
      required: true
      status: unavailable
      evidence: ""
      fallback: 'Inline scope-cut: single coherent deliverable (prose + its pinning C16 test land together); the wiring-heavy alternative was rejected to deleted_from_shape + a rabbit-hole.'
      rationale: opportunity-solution-tree not installed; decomposition is trivial (childless single vertical slice) and captured via deleted_from_shape.
    - phase: assumption-extract
      delegate: pol-probe-advisor
      required: true
      status: unavailable
      evidence: ""
      fallback: 'Inline POL probe: A1 (existing manual: schema is the behavioral gate) was the load-bearing assumption; cross-review disproved its strength, so it was reframed to criticality:critical with the honest ceiling (discoverability + regression, not enforcement).'
      rationale: pol-probe-advisor not installed; small-batch does not mandate it; the critical assumption was POL-probed inline and corrected by cross-review before the gate.
    - phase: acceptance-outcome
      delegate: press-release
      required: true
      status: unavailable
      evidence: ""
      fallback: 'Inline press-release framing: captain-observable outcome = a durable, discoverable, regression-pinned review-surface rule in ship-flow core.'
      rationale: press-release not installed; acceptance_outcome authored inline in user-observable form.
```
<!-- /section:pm-skill-receipts -->

## Appetite

small-batch

## Children



## Assumptions

(fill in at shape stage)

## Rabbit Holes

- codex-gate-mandatory-cross-vendor-verify-pilot

## Deletes

(fill in from deleted_from_shape)

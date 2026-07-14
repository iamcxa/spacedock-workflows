# Refresh root README stale compatibility claims — Shape

## Problem

The repository README is the adopter front door, but it duplicates product positioning and hardcodes old ship-flow and spacedock versions. Those literals are already stale and the existing version-triple check does not stop README drift from recurring.

## Acceptance Outcome

When onboarding readers open the repository README, they see version-independent compatibility and adoption guidance linked to PRODUCT.md, and the release gate rejects any reintroduced version-shaped literal such as v0.7 on its first CI run.

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
      fallback: Existing issue-backed shape states the reader harm, stale claims, and missing recurrence gate.
      rationale: The delegate is not installed in this runtime; the captain-supplied scope provides the required framing.
    - phase: scope-decompose
      delegate: opportunity-solution-tree
      required: true
      status: unavailable
      fallback: 'The confirmed fork is one bounded small-batch slice: README prose, negative grep, and RED-first coverage.'
      rationale: The delegate is not installed in this runtime; the captain explicitly selected fork (i).
    - phase: assumption-extract
      delegate: pol-probe-advisor
      required: true
      status: unavailable
      fallback: The critical assumption is that matching version-shaped literals catches future README drift without coupling to the current release number.
      rationale: The delegate is not installed in this runtime; repository inspection identified the check seam and current gap.
    - phase: acceptance-outcome
      delegate: press-release
      required: true
      status: unavailable
      fallback: The outcome is expressed as version-independent front-door guidance plus a first-CI-run rejection of reintroduced literals.
      rationale: The delegate is not installed in this runtime; the captain supplied the observable target and timing constraint.
```
<!-- /section:pm-skill-receipts -->

## Appetite

small-batch

## Children



## Assumptions

(fill in at shape stage)

## Rabbit Holes



## Deletes

(fill in from deleted_from_shape)

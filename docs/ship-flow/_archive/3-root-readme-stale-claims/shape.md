# Refresh root README stale compatibility claims — Shape

## Problem

The repository README is the adopter front door, but it duplicates product positioning and hardcodes old ship-flow and spacedock versions. Those literals are already stale and the existing version-triple check does not stop README drift from recurring.

## Acceptance Outcome

When onboarding readers open the repository README, they see version-independent compatibility and adoption guidance linked to PRODUCT.md, and the release gate rejects any reintroduced version-shaped literal such as v0.7 on its first CI run.

## Captain Bet

When this ships, the captain expects the root README to contain no hardcoded version literals and the recurrence gate to reject `v0.7`-style drift within the first CI run after merge. If not, this pitch was wrong about the Layer 1 claim that a negative-grep guard keeps front-door compatibility prose version-independent.

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

```yaml
children: []
```

This is one bounded small-batch slice: front-door prose, its recurrence guard, and focused RED-first coverage.

## Assumptions

```yaml
stated_assumptions:
  - id: A1
    claim: "A version-shape negative grep can reject README drift without coupling the check to the current release number."
    verified_by: codebase-inspection
    verification: "README contains multiple stale version spellings while scripts/check-version-triple.sh does not inspect the root README."
    confidence_at_shape: 95
    criticality: critical
  - id: A2
    claim: "PRODUCT.md is the canonical positioning source that the root README can link instead of duplicating."
    verified_by: canonical-doc-review
    verification: "PRODUCT.md already carries the maintained product positioning introduced by pitch 1."
    confidence_at_shape: 95
    criticality: important
```

## Rabbit Holes

```yaml
rabbit_holes: []
```

## Deletes

| Rejected | Reason |
| --- | --- |
| Refresh README literals to the current release numbers | New hardcoded values would become stale again and preserve the same failure mode. |
| Record README coupling without a negative grep | A coupling row documents ownership but does not mechanically reject version-shaped drift. |

## Acceptance Criteria

### AC-1 — no hardcoded version claims in root README

Root `README.md` contains no version-shaped release literal, including `v0.7`-style or bare semver variants.

Verified by: focused negative-grep tests and a direct scan of `README.md` both pass.

### AC-2 — positioning prose defers to PRODUCT.md

The README links `PRODUCT.md` for canonical positioning and does not duplicate paragraph-level product/version claims.

Verified by: reviewer comparison of the README front door against `PRODUCT.md`.

### AC-3 — recurrence is mechanically gated

`scripts/check-version-triple.sh` rejects version-shaped literals reintroduced into the root README, with RED-first coverage including a `v0.7` variant.

Verified by: the focused test demonstrates failure before implementation and passes after the gate is added.

## Canonical Doc Impacts

### Mandatory Updates

- `README.md` — replace hardcoded compatibility/adoption prose with version-independent guidance and a `PRODUCT.md` link.
- `scripts/check-version-triple.sh` — extend the existing release gate with a root README negative grep.
- focused shell tests — cover bare and `v`-prefixed version drift.

### Explicitly Unchanged

- `PRODUCT.md` remains the canonical positioning source; no content change is required.
- `ARCHITECTURE.md` has no component or runtime-boundary change.

## Hand-off to Design

```yaml
design_required: false
contract_decision_required: false
open_design_questions: []
open_contract_decisions: []
canonical_context:
  - PRODUCT.md
  - README.md
```

The design stage is a trivial pass: the captain already selected the gate strategy, no UI changes, domain model, or public contract choice remains.

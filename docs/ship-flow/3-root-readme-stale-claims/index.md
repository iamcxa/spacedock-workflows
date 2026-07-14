---
id: "3"
title: "Refresh root README stale compatibility claims"
status: verify
pattern: pitch
appetite: "small-batch"
shape_mode: mode-a
design_required: false
contract_decision_required: false
layout: folder
harvest_required: true
issue: "#22"
source: "todo root-readme-stale-claims (pitch 1 harvest)"
captain_bet: "When this ships, the captain expects the root README to contain no hardcoded version literals and the recurrence gate to reject v0.7-style drift within the first CI run after merge. If not, this pitch was wrong about the Layer 1 claim that a negative-grep guard keeps front-door compatibility prose version-independent."
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
acceptance_outcome: "When onboarding readers open the repository README, they see version-independent compatibility and adoption guidance linked to PRODUCT.md, and the release gate rejects any reintroduced version-shaped literal such as v0.7 on its first CI run."
stage_outputs:
  shape: shape.md

  design: design.md
  plan: plan.md
  execute: execute.md
pre_mortem:
  category: wrong-dcs
  one_liner: The grep misses a common version spelling, so README drift returns unnoticed.
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
| design | [design.md](design.md) |
| plan | [plan.md](plan.md) |
| execute | [execute.md](execute.md) |
<!-- /section:stage-artifact-links -->

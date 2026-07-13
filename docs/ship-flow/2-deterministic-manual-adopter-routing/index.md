---
id: "2"
title: "Deterministic manual adopter skill routing"
status: sharp
pattern: pitch
appetite: "small-batch (2-3 days)"
shape_mode: mode-b
design_required: true
contract_decision_required: false
layout: folder
harvest_required: true
children:
  - 2.1-manual-fail-closed-adopter-routing
rabbit_holes: []
deleted_from_shape:
  - claim: "Patch or retain the repository-scanning discovery helper"
    reason: "The captain rejected the helper strategy after repeated suppressible producer failures."
  - claim: "Redesign density classification or upstream spacedock status --discover (#24)"
    reason: "Separate existing issues outside this 2-3 day appetite."
  - claim: "Automatically migrate existing adopters or introduce multiple routing manifests"
    reason: "The selected contract keeps legacy configs readable and adds one canonical manual source."
acceptance_outcome: "When a new or manually onboarded adopter routes explicitly supplied task files, the captain receives exact skills and guidance from one committed manifest; missing or invalid routing stops before dispatch, and no production path scans the repository."
captain_bet: "修完後第一次真實執行且零錯誤 routing"
stated_assumptions:
  - id: A1
    claim: "The existing explicit manifest, resolver, downstream consumers, and receipt seams can support a strict fail-closed cutover within the appetite."
    verified_by: codebase-grep
    verification: "Static inspection of the manifest resolver and its focused tests; repository discovery and density classification are prohibited."
    confidence_at_shape: 90
    criticality: critical
  - id: A2
    claim: "Legacy source: discovered manifests can remain readable while all newly created manifests use source: manual."
    verified_by: design-contract
    verification: "Captain selected this compatibility contract during the Mode B question loop."
    confidence_at_shape: 85
    criticality: important
pre_mortem:
  category: hidden-dependency
  one_liner: "An overlooked stage bypasses strict resolution or receipt sequencing, letting an invalid manifest reach dispatch despite isolated tests."
stage_outputs:
  shape: shape.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->

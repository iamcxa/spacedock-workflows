# PRODUCT — ship-flow

> Skeleton bootstrapped at shape-confirm of the self-adoption dogfood pitch
> (2026-07-11). Completed to full flow-map-schema compliance by child
> `canonical-docs-bootstrap`.

Ship-flow is a staged feature-delivery pipeline (shape → design → plan →
execute → verify → review → ship) for autonomous AI coding agents, shipped as
a Claude Code plugin from this marketplace repo (`plugins/ship-flow/`).

## Current Capabilities

<!-- section:capabilities -->
| Capability | Domain |
| --- | --- |
| Staged pipeline stage skills (shape / design / plan / execute / verify / review / ship) | pipeline |
| Mechanical CI gates: check-invariants, check-no-dangling, check-version-triple, shell + node test suites | quality |
| Adopter sync and drift detection (`bin/sync-drift-check.mjs` + sync-manifest) | adoption |
<!-- /section:capabilities -->

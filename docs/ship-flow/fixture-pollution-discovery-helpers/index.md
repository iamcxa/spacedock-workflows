---
title: Fixture-tree exclusion for discovery helpers
status: shape
source: todo fixture-pollution-discovery-helpers (pitch 1 harvest)
started: 2026-07-12T13:48:06Z
completed:
verdict:
score:
worktree: .claude/worktrees/fixture-pollution-discovery-helpers
issue: "#20"
related_issue: "#24"
pr:
pattern: pitch
appetite: small-batch
layout: folder
answers_density: high
affects_ui: false
design_required: true
contract_decision_required: true
domain: schema
harvest_required: true
---

<!-- section:stage-artifact-links -->
| Stage | File |
| --- | --- |
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->

## Problem

`spacedock status --discover` and `plugins/ship-flow/lib/discover-adopter-skills.sh` both match plugin test fixtures when run inside the plugin repo. FO boot discovery lists 4 bogus workflow candidates from `plugins/ship-flow/lib/__tests__/fixtures/workflow-doctor/*` (reproduced at FO boot 2026-07-12 — forces `--workflow-dir` on every helper call); adopter-skill discovery drafts were unusable in pitch 1 shape (carlove-shaped routing from fixture content). WHO pays: every FO session in this repo, and shape-stage skill routing in any adopter repo that vendors fixtures.

Scope note: `status --discover` lives in the spacedock binary (upstream repo — debrief 2026-07-12-01 lists it as candidate upstream issue, not filed); the ship-flow-owned surface here is `discover-adopter-skills.sh` and any other lib/bin helper that walks the tree without fixture exclusion.

## Acceptance criteria

**AC-1 — discover-adopter-skills.sh ignores fixture trees.**
Verified by: running it from this repo root yields zero candidates sourced from `lib/__tests__/fixtures/**`; regression test with a fixture-shaped decoy tree.

**AC-2 — the exclusion rule is shared, not one-off.**
Verified by: a single exclusion helper/config consumed by every tree-walking lib/bin helper (grep shows no duplicated hardcoded fixture paths).

**AC-3 — upstream `status --discover` gap is filed or worked around.**
Verified by: GitHub issue link on the spacedock repo, or a documented `--workflow-dir` guard in this instance README.

## Shape State

The confirmed scope, captain Bet, dogfood checks, assumptions, pre-mortem,
canonical-doc decisions, and hand-off live in [shape.md](shape.md). The flat
draft above was absorbed without content loss; its original problem, scope
note, issue `#20`, and all three acceptance criteria remain verbatim here.

## Stage Report: shape

- DONE: Confirmed folder artifact preserves the flat draft's problem, scope
  note, issue `#20`, and AC-1 through AC-3 verbatim.
- DONE: Small-batch appetite is capped at 1-2 days; W1-W3 cover zero
  fixture-derived routes, one shared exclusion surface across every
  ship-flow-owned tree walker including `density-classify.sh`, and the
  documented upstream guard/tracker.
- DONE: Todo `fixture-pollution-discovery-helpers` is promoted and ROADMAP
  moves the entity from Later to Now.
- DONE: Upstream filing is approved and tracked locally by
  `iamcxa/spacedock-workflows#24`; this stage neither files nor implements the
  `spacedock-dev/spacedock` binary change.
- DONE: Shared-exclusion contract choices are handed to design; no
  implementation code, tests, or non-tree-walking helpers changed.
- FALLBACK: Native `shape-confirm.sh --layout=folder` exited 10 on the
  instance-native slug identity (`proposal missing pitch.id / pitch.slug /
  pitch.title`) and cannot absorb the existing flat entity, matching issue
  `#21`. The narrow mitigation migrated only shape/state artifacts and
  recorded the failure in `shape.md`.
- status: passed
- stage_cost: solo ensign shape/state migration; no implementation work

### Summary

Confirmed the fixture-safe discovery pitch as a 1-2 day small batch, preserved
the captain's draft and Bet, promoted its workflow state, and routed the shared
exclusion contract to design while keeping the upstream binary fix out of
scope.

### Metrics

- status: passed
- duration_minutes: 20
- iteration_count: 0
- path: shape+sharp
- open_contract_decisions_count: 3
- domain_matches_count: 1

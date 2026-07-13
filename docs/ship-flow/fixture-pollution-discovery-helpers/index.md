---
title: Fixture-tree exclusion for discovery helpers
status: plan
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

## Stage Report: design (cycle 2)

- DONE: Record the Science Officer route=narrow decisions as D1-D3 under the Captain's explicit delegation: sourceable Bash-only shared helper; requested-root-relative descendant __tests__/test-fixtures pruning; one-time complete walker audit plus simple single-definition/consumer invariant, without a permanent cross-language inventory framework.
  `design.md` records D1-D3 and the complete current production candidate audit.
- DONE: Replace PROMPT_CAPTAIN with a complete non-UI Hand-off to Plan: typed design_constraints for every D marker, open_decisions: [], focused RED/GREEN and first-real-run verification constraints, updated Design Report and Stage Report. Re-audit current recursive candidates including issues-to-contract.sh and sync-drift-check.mjs before any completeness claim.
  Seven typed constraints resolve all D markers; both required candidates are classified.
- DONE: Run applicable design validators and a fresh context-free read-only seven-factor review. Commit only design-stage artifacts; do not implement code, mutate entity status, advance stages, file upstream issues, or manage worktrees.
  Three validators passed and the independent read-only reviewer returned PROCEED on all factors.

### Summary

Revised the non-UI design to the EM's narrow delegated route, completed the
missing walker audit, and supplied plan-ready RED/GREEN and one-shot acceptance
constraints. No Captain decision remains; no implementation or status mutation
was performed.

## Stage Report: plan

- DONE: Import all seven design constraints mechanically and write a lean plan.md (body <=200 lines) with runnable DCs, exact task paths, safe wave metadata, per-task skills/reviewer questions, and complete canonical/context routing receipts.
  `plan.md` maps DC-1 through DC-7 onto four serial tasks; C4, C8, and C15 pass.
- DONE: Define strict TDD ledger contracts: focused RED/GREEN nested decoys for both consumers, positive fixture-root behavior, exit-0/empty-stderr/intended-output assertions, helper consumer/single-definition invariants, and the README #24 guard; reserve the real repo-root discovery command for one post-GREEN execution only.
  `tdd-ledger.txt` reports four valid records and persisted `tdd-ledger.jsonl` matches the current plan.
- DONE: Run plan validators, persisted TDD ledger proof, invariants, placeholder/scope checks, and a fresh seven-factor cross-review.
  Design/handoff/D-reference, ledger, full invariant, placeholder, diff, and context extraction checks pass; the replacement fresh reviewer returned seven-factor PROCEED and `skill-coverage: PASS`.

### Summary

Produced a bounded four-task implementation plan for one sourceable Bash helper, exactly two consumers, narrow invariants, and the documented one-shot acceptance stop gate. No implementation, status change, upstream filing, schema/API expansion, or worktree management was performed.

---
title: Make shape-confirm/allocate-id instance-aware
status: shape
source: todo shape-confirm-instance-awareness (pitch 1 harvest)
started: 2026-07-12T13:48:06Z
completed:
verdict:
score:
worktree:
issue: "#21"
pr:
---

`plugins/ship-flow/lib/shape-confirm.sh` and `lib/allocate-id.sh` ignore the workflow README's `id-style` declaration (this instance declares `id-style: slug`; allocate-id insists on numeric ids — exit 10 hit live in pitch 1), write the legacy vocabulary `status: sharp` at 3 sites (pitch 1 needed a sharp→shape reconciliation commit, 695adde, x4 occurrences), and never absorb an existing flat entity into folder layout (pitch 1 migrated four captain-written ACs by hand, then retired the flat file manually). WHO pays: every adopter whose instance README deviates from the tooling's baked-in assumptions — the confirm ceremony either hard-fails or silently writes vocabulary the status scanner rejects.

## Acceptance criteria

**AC-1 — id-style is read from the instance README, not assumed.**
Verified by: shape-confirm/allocate-id on an `id-style: slug` fixture instance completes without exit 10; regression test per id-style.

**AC-2 — zero legacy `sharp` writes.**
Verified by: `grep -rn "sharp" plugins/ship-flow/lib/shape-confirm.sh plugins/ship-flow/lib/allocate-id.sh` returns no status-writing site; scanner accepts confirm output with no reconciliation.

**AC-3 — confirm absorbs an existing flat entity.**
Verified by: fixture with a pre-existing flat `{slug}.md` (captain-authored ACs in body) — confirm migrates body content into the folder entity and retires the flat file in the same ceremony; test asserts no content loss.

## Reconciliation (2026-07-15)

PR #33 is not superseding coverage for this entity. Its mode-aware change covers
`pitch.shape_mode` receipt behavior for Mode A/B/C, not workflow-instance
`id-style` behavior. Fresh isolated runtime probes leave all three ACs open:

- AC-1: a slug-style proposal without a numeric `pitch.id` still exits 10.
- AC-2: `shape-confirm.sh` still writes `status: sharp` at three sites; the
  entity schema enum and live plugin README vocabulary still expose `sharp`.
- AC-3: confirming beside a pre-existing flat entity creates the folder while
  leaving the flat file and its captain-authored AC body in place.

Residual scope therefore remains the original three ACs with no narrowing by
PR #33. Captain approved retaining the full entity scope.

## Shape Decision (2026-07-21)

**Appetite:** small-batch (2-3 days). This is one vertical confirmation slice,
not an identity-system rewrite: read the selected workflow instance contract,
create its confirmed entity in current lifecycle vocabulary, and absorb a
same-slug flat draft without losing captain-authored content.

### Done-criteria proof matrix

1. **Instance identity:** fixture workflows cover Spacedock's three declared
   id styles: `slug`, `sequential`, and `sd-b32`. `slug` confirms with
   `pitch.id` absent and no numeric allocation; `sequential` preserves its
   zero-padded numeric contract; `sd-b32` uses its seed/actor minting contract.
   All three succeed without a silent numeric-prefix fallback.
2. **Lifecycle vocabulary:** every parent and shaped-child written by confirm
   uses a stage declared by that fixture README. The same fixture must pass a
   real `spacedock status --validate` and remain visible to dispatch analysis;
   validation alone is insufficient because today's scanner parses `sharp`
   but silently skips it when it is absent from `stage_by_name`. Live `sharp`
   writers and the schema/README vocabulary that blesses them move together.
3. **Flat-to-folder absorption:** a same-slug flat draft containing sentinel
   captain prose and acceptance criteria is confirmed to folder layout in one
   commit. The sentinel content remains byte-for-byte present, the flat path is
   absent, exactly one canonical entity resolves, and an induced pre-commit
   failure leaves the original flat entity intact.

### Recommended implementation boundary

- Core: `plugins/ship-flow/lib/shape-confirm.sh` and
  `plugins/ship-flow/lib/allocate-id.sh`; add one README id-style reader and one
  preflight migration plan before any write.
- Regression surfaces: `test-shape-confirm.sh`, `test-allocate-id.sh`, the real
  scanner/validation fixture, and schema validation tests.
- Contract sync: `plugins/ship-flow/skills/ship-shape/SKILL.md`,
  `plugins/ship-flow/references/entity-body-schema.yaml`, and only the live
  `sharp`/confirm wording in `plugins/ship-flow/README.md`.
- Explicitly out: split-root/state-checkout migration or two-root transaction
  design; upstream Spacedock task-by-slug/worktree resolution; historical
  archive rewrites; general migration between id styles.

The recommended design is a thin instance adapter inside the existing atomic
confirm ceremony. A slug-only special case is rejected because it would leave
the contract implicit; replacing the ceremony wholesale with repeated
`spacedock new` calls is also rejected because parent, children, todos,
ROADMAP, and flat retirement must remain one commit. Design must settle the
allocator's slug return contract, race-free `sd-b32` minting, per-style path
policy, shaped-child entry status, and compatible-frontmatter/body merge.

## Canonical Intent and Design Hand-off

- `PRODUCT.md`: skip — correctness of an existing internal capability.
- `ARCHITECTURE.md`: update at ship — document instance-declared identity and
  same-transaction flat-to-folder migration as responsibilities of the
  confirmation primitive.
- Root `README.md`: skip. Plugin README contract sync is in scope.
- Domain Registry Validation: `schema` (`classify` and `validate` both
  returned `status=ok`); `affects_ui: false`, `design_required: true`.
- Open contract decisions: slug allocator output plus race-free `sd-b32`
  minting; per-style filename policy and shaped-child entry status;
  compatible-frontmatter/body destination during absorption; rollback when
  any write, ROADMAP patch, validation, or commit step fails.

### Hand-off to Design

```yaml
affects_ui: false
domain: schema
design_required: true
contract_decision_required: true
ui_surfaces: []
open_design_questions: []
open_contract_decisions:
  - id: CD-1
    decision: Define the slug allocator return contract and the race-free sd-b32 minting contract.
    source_citations:
      - docs/ship-flow/shape-confirm-instance-awareness.md:51-55
      - docs/ship-flow/shape-confirm-instance-awareness.md:82-88
      - docs/ship-flow/shape-confirm-instance-awareness.md:97-102
  - id: CD-2
    decision: Define the per-id-style filename policy and the lifecycle entry status for shaped children.
    source_citations:
      - docs/ship-flow/shape-confirm-instance-awareness.md:51-61
      - docs/ship-flow/shape-confirm-instance-awareness.md:75-77
      - docs/ship-flow/shape-confirm-instance-awareness.md:86-88
  - id: CD-3
    decision: Define the compatible-frontmatter merge and the destination for preserved flat-entity body content during absorption.
    source_citations:
      - docs/ship-flow/shape-confirm-instance-awareness.md:62-66
      - docs/ship-flow/shape-confirm-instance-awareness.md:71-72
      - docs/ship-flow/shape-confirm-instance-awareness.md:86-88
  - id: CD-4
    decision: Define rollback semantics when any write, ROADMAP patch, validation, or commit step fails.
    source_citations:
      - docs/ship-flow/shape-confirm-instance-awareness.md:62-66
      - docs/ship-flow/shape-confirm-instance-awareness.md:82-86
      - docs/ship-flow/shape-confirm-instance-awareness.md:99-102
approved_boundaries:
  - boundary: Keep the design as a thin instance adapter inside the existing atomic confirm ceremony.
    source_citation: docs/ship-flow/shape-confirm-instance-awareness.md:82-86
  - boundary: Limit core implementation to shape-confirm.sh and allocate-id.sh, with one README id-style reader and one preflight migration plan before writes.
    source_citation: docs/ship-flow/shape-confirm-instance-awareness.md:70-72
  - boundary: Cover slug, sequential, and sd-b32 identity; declared lifecycle and dispatch visibility; and lossless atomic flat-to-folder absorption.
    source_citation: docs/ship-flow/shape-confirm-instance-awareness.md:49-66
  - boundary: Limit regression and contract-sync work to the focused tests, scanner/schema validation, ship-shape skill, entity-body schema, and live plugin README wording.
    source_citation: docs/ship-flow/shape-confirm-instance-awareness.md:73-77
approved_exclusions:
  - exclusion: Split-root or state-checkout migration and two-root transaction design.
    source_citation: docs/ship-flow/shape-confirm-instance-awareness.md:78-80
  - exclusion: Upstream Spacedock task-by-slug or worktree resolution.
    source_citation: docs/ship-flow/shape-confirm-instance-awareness.md:78-80
  - exclusion: Historical archive rewrites.
    source_citation: docs/ship-flow/shape-confirm-instance-awareness.md:78-80
  - exclusion: General migration between id styles.
    source_citation: docs/ship-flow/shape-confirm-instance-awareness.md:78-80
pm_framing_output: docs/ship-flow/shape-confirm-instance-awareness.md:42-102
```

## Stage Report: shape

- DONE: Prove slug id-style confirm succeeds without numeric allocation or exit 10, with regression coverage per supported id-style.
  Shape pins passing fixtures for `slug`, `sequential`, and `sd-b32`, including mandatory id-less slug success; implementation remains red today.
- DONE: Prove confirmation emits no legacy sharp lifecycle write and scanner accepts the resulting entity without reconciliation.
  Proof requires runtime validation plus declared-stage/dispatch visibility for parent and children, paired with schema and live README vocabulary tests.
- DONE: Prove a pre-existing flat entity is absorbed losslessly into folder layout and retired atomically, including captain-authored body content.
  Proof preserves sentinel captain prose byte-for-byte, resolves exactly one folder entity, deletes the flat path in the same commit, and exercises rollback.
- DONE: Report the narrow implementation boundary and explicitly exclude split-root migration or upstream task-by-slug resolution.
  Boundary is the two confirm/allocation helpers, focused tests, scanner/schema contract sync, and live docs; both exclusions are recorded above.
- DONE: Add the exact machine-readable Hand-off to Design block with source file-line citations, all four open contract decisions, and the approved boundaries/exclusions; preserve the approved Stage Report and do not advance status.
  The YAML hand-off records 21 valid source ranges, four decisions, four boundaries, and four exclusions; the original four report bullets remain and frontmatter is still `status: shape`.

### Summary

Re-shaped the existing issue #21 scope into one small-batch confirmation
transaction with executable identity, lifecycle, scanner, and lossless
migration proofs. Current HEAD and `origin/main` still satisfy 0/3 behavioral
ACs; this stage passes as a bounded specification and hands three contract
choices to design without claiming implementation success. Baseline focused
tests are green but encode the defects: allocator 13/13 numeric-only, entity
schema 33/33 without shape-vocabulary parity, and shape-confirm assertions that
still require `sharp`.

### Metrics

- status: passed
- duration_minutes: 28
- iteration_count: 0
- path: shape+sharp
- open_contract_decisions_count: 4
- domain_matches_count: 1

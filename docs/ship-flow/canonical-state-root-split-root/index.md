---
title: Migrate entity corpus to split-root state checkout
status: shape
appetite: medium
issue: "#85"
started: 2026-07-21T10:39:45Z
---

State-root split (separate entity corpus from code/tests/CI in .spacedock-state gitignore) requires simultaneous CI-enforcement migration: check-invariants scan must move to state-branch CI to prevent entity red findings from being hidden when corpus is off-main. This is a design+plan task (not 1h mechanical move) covering: state-checkout initialization, CI workflow relocation, check-invariants dual-env verification, and ARCHITECTURE.md update. Blocks later corpus-privacy work.

## Shape verification — 2026-07-21

**Disposition:** NARROW to one authority-transfer slice, then PARK at shape. Do not advance to
design until `shape-confirm-instance-awareness` is complete; the original approved ordering also
keeps open issue #75 ahead of this cutover. **Size:** M, medium appetite (1–2 weeks maximum).

### Captain articulation already given

Issue #85 names the user-visible failure: moving state off the code branch without moving its
mechanical enforcement would make red entity findings disappear. The captain batch-approved the
ordering R2 → R1 → roborev → #75 → split-root. FO-routed SO/EM review adds the narrower program
constraint: establish instance-aware identity before state authority; receipts, events, ROADMAP,
PR state, and future agent-native messages attest to lifecycle state but never author it.

### Problem evidence — two branches are acting as partial state stores

Evidence snapshot: controller `a94b31e`, `origin/main` `2ffee4b`.

- `git rev-list --left-right --count 2ffee4b...a94b31e` returns `384 84`: the controller is not a
  viable code base for the migration PR, and main is not a current lifecycle view.
- `git diff --stat 2ffee4b...a94b31e -- docs/ship-flow` reports 55 files, 2,289 insertions, and 8
  deletions. All 84 controller-ahead commits touch `docs/ship-flow`; the history contains repeated
  dispatch/advance, archive, add-todo, and explicit mirror commits rather than product-code work.
- The 2026-07-20 debrief says the dual-branch topology is behind most manual mirroring. The prior
  debrief names paired `pr`/verdict mirrors; commit `95de424` later mirrors an archive back from main.
- The trees are complementary, not safely selectable wholesale: the controller has 123 tracked
  workflow files while `origin/main` has 156; `git diff --name-status a94b31e..2ffee4b --
  docs/ship-flow` contains 80 additions, 47 deletions, modifications, and moves. Main contains fuller
  stage evidence for several PR entities while the controller has newer lifecycle placement, todos,
  and debriefs.
- `CI=true bash plugins/ship-flow/bin/check-invariants.sh` at `a94b31e` exits non-zero with eight C14
  findings. Those are real baseline debt. A successful migration preserves the normalized finding
  set and a red state-branch run; it must not obtain green by scanning only main's partial corpus.

### Shaped authority contract

The single authoritative lifecycle root is the orphan branch `spacedock-state/ship-flow`, checked
out at the gitignored `docs/ship-flow/.spacedock-state/`. The code branch retains the workflow
definition (`docs/ship-flow/README.md`), `_mods/`, plugin code/tests, canonical product docs, and
the code CI workflow. The state root owns active entities, `_archive/`, `_debriefs/`, `todos/`, and
their stage artifacts. No entity is live beside the definition after cutover.

Entity frontmatter in that checkout is the lifecycle authority. Commits/receipts, PR/provider
state, ROADMAP rows, scheduler events, and later typed agent messages are evidence or projections.
They may reconcile from the entity root, but they cannot independently advance it.

### Cheapest vertical migration slice

1. **Make checks and the minimum live writers root-aware without changing the live backend.** Add a
   definition-root/entity-root resolver and fixtures proving the same entity checks and finding
   identifiers under `$inline` and split-root layouts. Code checks scan the checked-out event SHA/PR
   head, with `origin/main` only as the explicit history base; state checks scan the state event SHA
   and explicit state-history base. Adapt shape-confirm, stage-artifact writes, archive/debrief reads,
   todo creation, and the PR mod before cutover.
2. **Build and clear a deterministic seed under a write freeze.** Use updated `origin/main` for
   code/definition assets, controller state for lifecycle frontmatter and active/archive placement,
   and union immutable main-only stage evidence by slug after the instance-awareness prerequisite
   makes identity lossless. Every destination records source ref + blob hash; unresolved same-path
   conflicts HALT. Seed/push `spacedock-state/ship-flow` with a thin state-branch Actions workflow;
   reproduce and repair every inherited failure there until the required state gate is green. Do not
   merge or rebase `iamcxa/muscat-v1` into main.
3. **Only then switch authority.** Add `state: .spacedock-state` + the gitignore entry on main,
   remove inline entity copies, and verify the green state event SHA plus status/discovery/re-entry
   proofs before ending the freeze. There is never a dual-write phase, and red state CI cannot be
   followed by authority switch or inline deletion.

This slice deliberately does not add worker capability routing, lean/full policy, telemetry,
Crewdock export, push notification, corpus privacy, automatic adopter migration, or a lifecycle
event-ledger redesign. Those later agent-native consumers depend on the canonical address established
here: definition ref + state branch + entity slug + state commit SHA.

### Typed done criteria

**DC-1 — Lossless, single-root corpus.** A checked-in migration-manifest test accounts for every
non-definition blob from both snapshot refs as `state-authoritative`, `evidence-union`, `definition`,
or explicitly rejected; unresolved/conflicting rows are zero. Each live slug resolves once under
`.spacedock-state`, and no active entity/archive/todo/debrief remains beside the definition.
Verified by: fixture-backed `test-split-root-migration.sh`, `git ls-tree` blob-hash comparison, and
`spacedock status --workflow-dir docs/ship-flow --validate`.

**DC-2 — One lifecycle writer.** Status mutation, archive, debrief, and stage-report fixtures change
only the state checkout; the code checkout remains porcelain-clean. Receipts/events/projections
cannot mutate lifecycle state without the existing graph/CAS path.
Verified by: split-root mutation fixture plus before/after `git status --porcelain` and state/code
HEAD assertions.

**DC-3 — CI failure parity, not cosmetic green.** Injecting the same bad entity into inline and
split-root fixtures yields the same normalized check IDs and non-zero exit. The first live
state-branch run reproduces the cutover snapshot's known finding set (currently eight C14 findings)
or documents fixes by commit; no missing finding may be explained by an unscanned root. The required
state gate becomes green only after those findings are repaired by explicit commits—never by a
baseline/allowlist—and cutover remains incomplete while it is red.
Verified by: dual-layout invariant test and `gh run view` for the state event SHA.

**DC-4 — State sync is multi-writer safe.** Two clones commit disjoint entity paths, encounter the
expected non-fast-forward, pull/rebase, and re-push to one linear state branch without loss. A
same-entity conflict aborts and never force-pushes or selects ours/theirs.
Verified by: two-writer real-Git fixture mirroring Spacedock's state sync contract.

**DC-5 — Discovery has one definition and one corpus.** Repository discovery returns the commissioned
definition once, prunes `.spacedock-state` as a nested workflow candidate, and resolves status/new/
dispatch through the definition README to entities in the checkout.
Verified by: discovery fixture plus JSON assertions on `definition_dir`, `entity_dir`,
`state_backend=split-root`, and the dispatched absolute entity path.

**DC-6 — Fresh-session re-entry is deterministic.** In a fresh clone, boot reports the declared
checkout absent; `spacedock state init --workflow-dir docs/ship-flow` materializes
`spacedock-state/ship-flow`; a second init is a no-op; boot/status and dispatch then find the same
entity, while the code branch stays clean.
Verified by: fresh-clone real-Git fixture and an installed-binary smoke test.

**DC-7 — Rollback restores one root without losing post-cutover state.** A rehearsed rollback freezes
writes, snapshots state HEAD, reverts the main cutover, and deterministically exports the captured
orphan tree under `docs/ship-flow/` with path translation for additions, modifications, deletions,
and renames. It verifies identical slug/blob inventory before reopening writes. The abandoned state
branch remains audit history, never a concurrent writer; ordinary cherry-pick/replay is forbidden
because the orphan branch has a different tree root.
Verified by: temporary-clone rollback drill with path-translation, manifest/hash, deletion/rename,
and status assertions.

### Compatibility, rollback, and dependency boundaries

- Other adopters keep `$inline` as the backward-compatible default; this is an instance migration,
  not automatic adopter migration. Callers continue pointing `--workflow-dir` at the definition,
  never at the checkout and never at a copied README inside it.
- Implementation worktrees branch from updated `origin/main`; the seed manifest reads the frozen
  controller snapshot as data. No implementation commit is based on the 384-commit-behind controller.
- `shape-confirm.sh` currently couples entity/child/todo creation and ROADMAP projection in one
  repository commit. Design must define ordered state-root commit + code-root projection with a
  recoverable compensation/retry boundary; the migration must not pretend cross-root atomicity.
- Hard gate: complete `shape-confirm-instance-awareness` (#21) first so slug identity, current status
  vocabulary, and flat-to-folder absorption are lossless. Original batch gate: #75 must be terminal
  unless the captain explicitly changes that ordering. This entity remains `status: shape` meanwhile.
- Pre-cutover state CI may remain honestly red while inherited findings are repaired. Required-gate
  activation and cutover completion wait for real fixes; suppressing, baselining to green, or
  dropping the state scan is not rollback.

### Rejected alternatives

- Keep `iamcxa/muscat-v1` as a permanent controller branch and mirror fields/artifacts — rejected by
  the measured divergence and repeated manual mirror commits.
- Copy the corpus into `.spacedock-state` but leave CI only on main — rejected because it converts
  today's eight visible C14 failures into false green by omission.
- Merge the controller branch into main — rejected because it mixes stale code with lifecycle data
  and still leaves routine state churn in product history.
- Add an external state repository or dual-write bridge — rejected as unnecessary auth/ops surface;
  Spacedock already supports a same-repo orphan state branch and path-scoped sync.

### Canonical intent and hand-off to design

- **ARCHITECTURE.md: update required.** Replace the inline `entitystate` container with definition +
  orphan-checkout roots, name entity frontmatter as lifecycle authority, classify receipts/events/
  ROADMAP/PR as projections, and show code-CI vs state-CI data flow.
- **PRODUCT.md: no change.** This migrates internal persistence/enforcement without changing the
  staged-delivery promise or adding a new user capability.
- **ROADMAP.md intent:** keep parked out of Now until prerequisites close; add to Now only when the
  design/plan lane is legally resumed. No canonical document is patched during shape.
- **README impact:** update the workflow frontmatter, state initialization/re-entry instructions,
  commit/sync discipline, and the explicit definition-vs-entity-root boundary.
- **Domain:** `registry-resolve --classify` returns `matched=schema`; validation returns `status=ok`.
  Adopter `domains.yaml` / `skill-routing.yaml` are absent, so design must use the repo-local schema
  lane and record that fallback.
- **Open contract decisions for design:** (1) select and pin the checker interface separating code
  root, definition root, entity root, state Git root, and history base; (2) define shape-confirm's
  two-root ordering/compensation and whether state CI consumes latest main or a recorded checker SHA.
  Plan must not silently infer any of these from CWD.

## Domain Registry Validation

- classify: `bash plugins/ship-flow/lib/registry-resolve.sh --classify docs/ship-flow/canonical-state-root-split-root/index.md`
- validate: `bash plugins/ship-flow/lib/registry-resolve.sh --validate --domain=schema`
- domain: schema
- result: proceed after prerequisites; currently PARK at shape

## Stage Report: shape

- DONE: Prove the current dual-branch/manual-mirroring cost and define one authoritative state root without hiding CI failures.
  Snapshot `2ffee4b...a94b31e` proves 384/84 divergence, 55 changed state files, repeated mirror/state commits, and eight still-visible C14 failures; authority is `spacedock-state/ship-flow`.
- DONE: Cut the cheapest vertical migration slice with explicit compatibility, rollback, and dependency boundaries for the later agent-native program.
  Three-step resolve/manifest/cutover slice defined; `$inline` compatibility and rollback drill retained; capability routing, profiles, events, telemetry, delivery, privacy, and adoption are excluded.
- DONE: Produce typed acceptance/done criteria with reproducible code-level evidence for state sync, discovery, and session re-entry.
  DC-1..DC-7 bind fixture commands, real-Git sync/discovery/re-entry proofs, CI finding parity, and a rollback rehearsal.

### Metrics

- status: passed
- duration_minutes: 45
- iteration_count: 0 (captain articulation and batch approval already recorded)
- path: shape-only
- open_contract_decisions_count: 2
- domain_matches_count: 1

### Summary

Shaped a fail-preserving transfer from two partial branch stores into one native split-root authority,
with deterministic content reconciliation instead of a branch merge. The artifact keeps inherited CI
red visible, pins sync/discovery/fresh-session/rollback proofs, and explicitly parks the entity at the
shape gate until instance-aware confirmation (#21) and the approved #75 predecessor are complete.

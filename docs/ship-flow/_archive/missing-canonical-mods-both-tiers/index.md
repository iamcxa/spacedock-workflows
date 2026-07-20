---
title: Add missing canonical mods (architecture-canon, doc-sync)
status: done
issue: "#84"
worktree: .worktrees/spacedock-ensign-missing-canonical-mods-both-tiers
started: 2026-07-20T02:00:35Z
verdict: rejected
completed: 2026-07-20T02:51:05Z
archived: 2026-07-20T02:51:05Z
---

architecture-canon.md and some canonical-doc-sync.md references resolve in NEITHER plugin nor adopter tier (mod exists nowhere — different class from the re-point fix; twin-exists guard deliberately does not flag them). Discovered during rra shaping; needs authoring or reference removal.

## Shape

Size: **S → RESCOPED to NO-OP** (see disproof). Appetite / time budget: **0h** for the originally-described greenfield authoring; **~15m** for the retire/close decision this shape files. Articulation covered by captain batch attestation 「這批都核准」 (hackathon-2 round 2 flip ordering, issue #84 body). Not re-litigated.

**Baseline: origin/main @ `cd77e92`** (NOT the working tree — this branch `iamcxa/muscat-v1` is 300 behind main and 51 ahead).

### Reverse-recovery disproof — the abstractions ALREADY EXIST on origin/main

Applying `reverse-recovery-audit` (assume it exists, prove what's missing) against origin/main, the two mods are NOT missing there — they were shipped as part of the sibling entity `missing-canonical-mods` (issue #77, PR #79, archived 2026-07-20). The current entity `missing-canonical-mods-both-tiers` is a **stale-todo duplicate** — the todo (`docs/ship-flow/todos/missing-canonical-mods-both-tiers.md`) was captured 2026-07-19T15:17:46Z during rra shape discovery, BEFORE #77 was shaped/executed/merged on the same night's hackathon-2 pipeline. The captain's batch attestation swept it up (round 2, 2026-07-20) without noticing the overlap with a same-night-shipped sibling.

Ground truth per `git ls-tree origin/main` + `git grep origin/main` (verified 2026-07-20):

- `docs/ship-flow/_mods/canonical-doc-sync.md` — **EXISTS on origin/main** (authored by commit `590b1e6` "feat(canonical-doc-sync): author adopter-tier mod content contract (AC-1)"). Adopter-tier path deliberate: the sibling shape rejected plugin-path authoring on load-bearing grounds (would force every adopter-tier ref through the #71 resolver's mislocation branch, creating churn). Content recovered from the tests' own 13-token contract (`test-canonical-doc-sync-mod.sh` / `test-canonical-context-lifecycle.sh`).
- `plugins/ship-flow/_mods/architecture-canon.md` — **NOT AUTHORED (deliberate).** The sibling shape classified it DE-REFERENCE, not MISSING-recover. All 3 bibliographic refs removed on origin/main by commit `785e391` "fix: de-reference dangling architecture-canon and decisions-log mods (AC-1, F1)": `ship-shape/SKILL.md:596`, `ship-plan/SKILL.md:501`, `_mods/migrate-debrief-vN-to-vN+1.md.template:33`. Rationale on record: no live consumer, no test asserts content, no recoverable content spec, functional territory (ARCHITECTURE.md doc-timing) already owned by `canonical-doc-sync.md`.
- **Missing-everywhere guard** — the AC-2 mechanical guard extending `scripts/check-no-dangling.sh` for the no-twin-no-adopter class also landed as part of PR #79 (proven live on origin/main).

The working branch `iamcxa/muscat-v1` (this worktree's base) is 300 behind origin/main and lacks all of PR #79, so a naive grep in this worktree still shows the OLD dangling refs at `ship-shape/SKILL.md:596` + `ship-plan/SKILL.md:501`. That is a **branch-reconciliation artifact, not a real gap**. Doing the "authoring" here would either (a) reinvent files already committed on main and force a merge conflict at reconcile, or (b) confirm the origin/main content via a null-diff PR — either way, zero product value and a duplicated ship-flow ledger row.

### Per-mod decision (post-disproof)

- `architecture-canon.md` (both tiers) → **NO-OP.** Canonical decision recorded on origin/main is DE-REFERENCE. Do not author. Re-authoring contradicts the shipped sibling decision (`docs/ship-flow/_archive/missing-canonical-mods/index.md:49-53` + commit `785e391`).
- `canonical-doc-sync.md` (adopter tier) → **NO-OP.** Already authored on origin/main at `docs/ship-flow/_mods/canonical-doc-sync.md` (commit `590b1e6`). Do not re-author. Do not port a second copy to the plugin tier (see load-bearing rationale above).

### Recommendation — RETIRE this entity, close #84 as duplicate-of-#77

1. **File this shape as the entity's terminal artifact.** No design / plan / execute follows.
2. **Close GitHub issue #84** with a comment linking to #77 / PR #79 / archived `docs/ship-flow/_archive/missing-canonical-mods/` and citing this shape as the disproof.
3. **Archive this entity** into `docs/ship-flow/_archive/missing-canonical-mods-both-tiers/` with a `retired-duplicate` verdict (or the workflow's equivalent), so the debrief harvester can surface stale-todo-vs-shipped-sibling duplication as a class worth guarding against at intake.
4. **Do NOT reconcile `iamcxa/muscat-v1` → `origin/main` under this entity's scope.** That is a broader task called out both in the sibling shape's BLOCKING risk and in the 2026-07-20 debrief's `Issues — Workflow` bullet on "dual-branch state topology." Route it through the pending `canonical-state-root-split-root` entity or a dedicated reconcile pitch.

### Two-independent-authoring-tasks framing (dispatch checklist item 3)

The dispatch checklist called for shaping "the two independent authoring tasks (plugin tier + adopter tier)." Under the reverse-recovery discipline, **the correct answer for both tiers is NO authoring task**: one is a shipped no-op (adopter-tier canonical-doc-sync) and the other is a shipped DE-REFERENCE (plugin-tier architecture-canon). The checklist item is SATISFIED by the null result, not by fabricating two make-work tasks. This is the reverse-recovery rule at bind time (shape) — the stage-def's Bad Signs explicitly names "greenfield tasks without proof the abstraction is missing" as shape-quality failure.

### Out of scope

- Any authoring, de-referencing, or guard-mechanism work in either tier (all already shipped on origin/main per #77 / PR #79).
- Branch reconciliation `iamcxa/muscat-v1` → `origin/main` (separate scope; see `canonical-state-root-split-root` and 2026-07-20 debrief).
- The #71 resolver hardening (`no-dangling-guard-qualifier-precision` / #75, sibling entity).
- Third-party deps, spacedock binary version, adopter-repo templates.

### Risk — the retire recommendation itself needs captain confirmation (bad news early)

The dispatch prompt frames this as a live authoring job with a three-item checklist. Recommending RETIRE cuts against the batch attestation. Captain confirmation is the correct next gate — either:

- (a) **CONFIRM retire** → FO closes #84, archives entity, moves on. Recommended.
- (b) **REJECT retire, insist on re-authoring** → escalates the underlying issue: rebase `iamcxa/muscat-v1` to `origin/main` is a hard prerequisite; without it we edit phantom files, exactly the risk the sibling shape flagged BLOCKING and the captain took the "route through origin/main" fix on. Under (b), execute pre-work is a reconcile task, not the ACs stated here.

Do NOT silently proceed to `design` on the assumption of (a). This is a shape gate the human owns.

## Stage Report: shape

- DONE: Identified both missing mods: architecture-canon.md and canonical-doc-sync.md references
  Both located on the stale working branch (ship-shape/SKILL.md:596, ship-plan/SKILL.md:501, migrate-debrief:33 for architecture-canon; ship-review/SKILL.md live-load path for canonical-doc-sync) AND cross-checked against origin/main@cd77e92 — where architecture-canon refs are already removed (commit 785e391) and canonical-doc-sync.md already exists at the adopter path (commit 590b1e6).
- DONE: Defined authoring or removal decision for each missing mod
  architecture-canon → NO-OP (shipped DE-REFERENCE, do not author); canonical-doc-sync → NO-OP (shipped adopter-tier author, do not re-author or port to plugin tier). Recorded in `## Shape → Per-mod decision`.
- DONE: Shaped the two independent authoring tasks (plugin tier + adopter tier)
  Correct shape under reverse-recovery is ZERO authoring tasks (null result satisfies the checklist honestly rather than fabricating make-work). Recorded in `## Shape → Two-independent-authoring-tasks framing`. Retire recommendation filed as the terminal artifact instead of design/plan/execute.

### Summary

Reverse-recovery audit disproved the entity's greenfield framing: both mods are already shipped on origin/main via the sibling entity `missing-canonical-mods` (#77 / PR #79, archived same night the todo was captured). This entity is a stale-todo duplicate that the captain's hackathon-2 round 2 batch attestation swept up without noticing the overlap. Recommendation: RETIRE this entity, close #84 as duplicate-of-#77, do NOT reconcile stale branch under this scope. Captain confirmation of the retire is the correct next gate (bad news early — do not silently proceed to design).

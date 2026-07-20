# Terminalize the stuck roborev entity — Shape

### Summary

Archive-as-parked. The stuck flat entity `roborev-migration-receipt-merge-semantics`
(status: execute since 2026-07-13) moves to `docs/ship-flow/_archive/` with honest
terminal frontmatter on a main-based branch → PR to main → PR #80's corpus-wide
invariants scan clears on its next re-run. Zero product code; the operation is
inside the FO's write scope (archive moves + frontmatter), so no worker dispatch —
FO executes directly with evidence recorded here. Size S.

### Decision basis (L0, fresh-subagent, 2026-07-20)

- **Nothing to backfill:** origin/main's trail for the entity is status-transition
  commits only (`cf9edf9`→`3f08b7f`→`55911b8`→`a7756f9`) — no task-level work ever
  landed. The real implementation lived on a never-pushed local branch
  (`spacedock-ensign/roborev-migration-receipt-merge-semantics` @ `d175178`,
  yangon workspace, preserved by SHA — not deleted by this entity), never PR'd,
  AC-3 RoboRev gate never run, deliverable files absent from main.
- **Intent survives elsewhere:** deterministic migration receipts / merge-parent
  semantics are already tracked by open issues #36 and #37 from a different,
  staged branch. Backfilling the orphan would duplicate/conflict with that work.
- **Failing checks + why archive clears them:** `check_section_tag_coverage`
  (skips `*_archive*`, check-invariants.sh:194) and `check_pre_mortem_emitted`
  (glob `docs/ship-flow/*.md` cannot match one level under `_archive/`,
  check-invariants.sh:820); terminal predicate accepts `status: done`
  (check-invariants.sh:59-61).
- **Reconciler path unavailable by design:** entity has no `pr:` field →
  merged-pr-closeout-reconciler rejects `missing-pr` (:394). Precedent
  `missing-canonical-mods-both-tiers` (#84): direct frontmatter + archive via
  `merge guard --verdict rejected`; terminal entities without a PR carry no
  `pr:` field (checker-confirmed non-blocking).
- **Where it lands:** invariants CI checks out the PR's synthetic merge commit
  and scans the whole corpus (ship-flow-invariants.yml:29-33, unscoped run) —
  a separate archive-only PR to main suffices; #80 clears on its next
  synchronize/re-run after main advances.

### Acceptance criteria (inherited from index.md, evidence plan)

- **AC-1** (#80 invariants green): archive PR merges → `gh pr update-branch 80`
  → fresh invariants run green. Verified by: the check run conclusion.
- **AC-2** (corpus-honest, no allowlist): diff = one file move + frontmatter
  terminalization + body postscript; zero checker edits. Frontmatter per
  precedent: `status: done`, `verdict: REJECTED` (parked — nothing shipped),
  `completed:`/`archived:` timestamps, no `pr:` field. Body postscript records
  the parked rationale + pointers (#36/#37, local branch SHA `d175178`).

### Pre-mortem (hidden-dependency)

Main's corpus may hide a SECOND invariants offender that roborev's noise masked —
the archive PR's own full-corpus run is the detector; if it stays red, the new
offender surfaces there and this entity's scope ends at reporting it.

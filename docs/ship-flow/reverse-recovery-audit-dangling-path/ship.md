# Fix dangling reverse-recovery-audit adopter-local mod reference — Ship

Issue #69 fixed: `ship-shape/SKILL.md` and `ship-plan/SKILL.md` now lead
with the plugin-canonical `reverse-recovery-audit.md` path (adopter path
demoted to a "when present" override), and `check-no-dangling.sh` gained a
twin-exists + qualifier-aware resolver so this reference class is
mechanically regress-guarded going forward.

## Todo Closeout Digest

- W1 (WARNING): bare `override` qualifier term is over-broad — scope the
  match to the listed phrases only, or require same-sentence proximity.
- W2 (WARNING): upward logical-unit scan should also stop when the match
  line is itself a self-contained list-item start.
- W3 (advisory): broaden qualifier allowlist for plausible legit phrasings
  ("if present", "falls back to", "defaults to the plugin copy").
- W4 (advisory): add `|| true` to the `grep -c` at
  `check-no-dangling.sh:300` for robustness against format drift.
- W5 (advisory): strengthen fixture cases 6/7 in
  `test-check-no-dangling.sh` so their names match what they exercise.
- Pre-existing, out-of-scope: `check-invariants.sh`'s `_entity_is_terminal()`
  misclassifies any entity with an empty `completed:` field as terminal,
  repo-wide — separate ticket.
- Carried from shape.md: `architecture-canon` / `canonical-doc-sync` mods
  missing in both plugin and adopter tiers; broader doc audit; sync-manifest
  redesign. Not this entity's scope.

## Canonical Docs Update

- PRODUCT.md: skip — extends an already-documented capability row, no new
  capability.
- ARCHITECTURE.md: skip — no new component/contract.
- ROADMAP.md: update recorded (Later → Shipped for this row), **deferred to
  done/closeout on the canonical root** — not patched in this worktree/PR.

### Canonical Doc Actions Consumed

| Doc | Action Source | Plan Action | Review Outcome | Commit Or Skip Rationale |
| --- | --- | --- | --- | --- |
| PRODUCT.md | plan.md | skip | skipped | extends existing capability row |
| ARCHITECTURE.md | plan.md | skip | skipped | no new component/contract |
| ROADMAP.md | plan.md | update, deferred to ship | deferred further, to done/closeout | Later→Shipped row move not patched here; canonical root, not worktree, per ship checklist |

### Token + Release

Token: not tracked (no `size`/`token_budget` stamped on this entity; no
fabricated figures). Version: no plugin bump this ship — repo convention
batches bumps into separate `chore(ship-flow): release X.Y.Z` commits
(0.9.0 unchanged); this fix is additive-only, no existing contract changed.

### Verdict
status: awaiting_merge
pr: "#71"
tasks: 3/3 (T1/T2/T3, plan.md)
verify: PASS (PROCEED) — verify.md, independent re-run
dependency: supersets PR #70 (l3-scheduler-tick); merge #70 first

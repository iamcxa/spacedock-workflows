# L3 scheduler tick — Ship

Approved (`sd:approved`) shaped work now reaches a trustworthy PR-ready
queue unattended via an idempotent scheduler tick — human keeps sole merge
authority (no auto-merge), audit-by-exception via a deterministic rollup.

## Todo Closeout Digest

- Deferred follow-ups (verify.md `## Deferred to TODO`, plan.md cut-list):
  W3+W5 lease recovery/release races (atomic rmdir+mkdir CAS takeover,
  strict token match); W4 reconciler crash-resumability under the new
  `timeout` bound; rollup cost field n/a; launchd install stays manual (no
  installer script); multi-epic `advance` scan absent (single-epic v0
  only). None narrow an AC.
- Rejected, not captured as todos: shape.md's nine "Deferred without loss"
  policy refusals (raw intake, auto-merge, repair-until-pass, auto
  codex-gate, helm/Linear/crewdock, semantic nightly learning, frontend
  design classifier).
- Cross-cutting gap relayed from separate rra shaping (not this entity's
  scope; independently confirmed absent here): `_mods/architecture-canon.md`
  and `_mods/canonical-doc-sync.md` are referenced by ship/ship-review
  SKILL.md but exist in neither the plugin nor adopter `_mods/` tier — own
  follow-up todo needed.
- Promoted into shaped entities this run: none.

## Canonical Docs Update

- ROADMAP.md: 80c31e1 — Now row for l3-scheduler-tick
- ARCHITECTURE.md: b95cce3 — carrier-swap scheduler-tick decision
- PRODUCT.md: 9c8b67a — unattended PR-ready-queue capability
- INVARIANTS.md (plugin): skipped — no invariant change at v0; the ten hard
  rules are v0 contract, not plugin invariants (shape/design/plan concur)

### Canonical Doc Actions Consumed

| Doc | Action Source | Plan Action | Review Outcome | Commit Or Skip Rationale |
| --- | --- | --- | --- | --- |
| ROADMAP.md | design §11 | skip (defer to ship) | updated | 80c31e1 |
| ARCHITECTURE.md | design §11 | skip (defer to ship) | updated | b95cce3 |
| PRODUCT.md | design §11 | skip (defer to ship) | updated | 9c8b67a |
| INVARIANTS.md (plugin) | design §11 | skip | skipped | no v0 invariant change |

### Token + Release

Token: not tracked (captain-directed hackathon shape; no
`size`/`token_budget` stamped at creation — no fabricated figures). Version:
no plugin bump this ship — repo convention batches bumps into separate
`chore(ship-flow): release X.Y.Z` commits (0.9.0 unchanged across the last
4 merged PRs); this v0 wedge is additive-only, no existing contract changed.

### Verdict
status: shipped
pr: "#70"
tasks: 8/8 (T0-T7, plan.md)
verify: PASS (PROCEED) — verify.md cycle 3, final
roadmap: Now row added (80c31e1)
product: capability row added (9c8b67a)
started_at: 2026-07-19T10:37:35Z
completed_at: 2026-07-19T11:01:39Z
duration_minutes: 24

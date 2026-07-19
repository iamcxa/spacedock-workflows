---
title: Fix dangling reverse-recovery-audit adopter-local mod reference + regress-guard
status: shape
source: todo reverse-recovery-audit-dangling-path (pitch 5) + captain 票ok 2026-07-19 (L3 tick real-proof ticket)
started: 2026-07-19T02:37:40Z
completed:
verdict:
score:
worktree:
issue: "#69"
pr: "#71"
---

ship-shape/SKILL.md:597 and ship-plan/SKILL.md:502 reference adopter-local
docs/ship-flow/_mods/reverse-recovery-audit.md which does not exist; the plugin-canonical
copy plugins/ship-flow/_mods/reverse-recovery-audit.md exists (3.7K). check-no-dangling.sh
misses this reference class. Small (S), non-UI, mechanical. This entity doubles as the live
single-entity proof for the L3 scheduler tick: after shape it must satisfy dual-key
eligibility (shaped + issue #69 labeled sd:approved) and be dispatched by the tick, not by hand.

## Acceptance criteria

**AC-1 — The referenced mod path resolves.** [Shape-resolved: fix (b).] The two SKILL references
(ship-shape:597, ship-plan:502) lead with the plugin-canonical path
`plugins/ship-flow/_mods/reverse-recovery-audit.md` (present in the source repo), with the adopter
path `docs/ship-flow/_mods/reverse-recovery-audit.md` demoted to a "when present" override — matching
the science-officer-em / contribution-contract convention. Materialize-in-adopter (a) rejected; see
shape.md Decision + Deletes.
Verified by: the grep that today returns a dangling reference returns a resolving one.

**AC-2 — The reference class is mechanically regress-guarded.** [Shape-resolved.] A twin-exists +
qualifier-aware mod-reference resolver (new pass in check-no-dangling.sh or an equivalent wired CI
check) fails on a fixture of this class — adopter `_mods/<name>.md` absent while the plugin twin
exists, referenced unconditionally — and passes on the fixed tree; see shape.md Guard spec.
Verified by: the check run red on a synthetic dangling fixture, green on the repo.

**AC-3 — Existing suite green.** The 110+ shell-test suite and CI gates pass unchanged.
Verified by: test suite run output.

## Stage Report: shape

- DONE: LEAN shape for an S mechanical ticket — decide the cheaper honest fix between (a) materialize/sync vs (b) reconcile SKILL references; record rejected alternative with one-line reason.
  Chose (b): re-point both SKILL refs to the plugin-canonical path with adopter "when present" override; shape.md Decision + Deletes. Evidence: mod header (reverse-recovery-audit.md:8-11) says only adopters copy to docs/_mods; no sync-manifest.json here (sync-drift-check dormant); science-officer-em/contribution-contract already follow this convention.
- DONE: The regress-guard is a code gate — name where check-no-dangling.sh misses this class and specify the fixture-backed test.
  Miss: it is a fixed denylist of known-dead literal strings with zero path resolution, and SCAN_ROOT is plugins/ship-flow only while the target is under docs/ship-flow. Guard = twin-exists + qualifier-aware resolver; fixture test RED (unqualified ref, twin present, adopter absent) / GREEN (fixed, qualified, no-twin) in shape.md Guard spec.
- DONE: Do NOT re-ask captain articulation; appetite S; record out-of-scope.
  Articulation cited from todo pitch 5 + issue #69 + captain 票ok, not re-litigated. Appetite S recorded. Out-of-scope: architecture-canon / canonical-doc-sync (different class — mod exists in neither tier), broader doc audit, sync-manifest redesign.

### Summary

Chose fix (b) — reconcile the two SKILL references to the plugin-canonical path (adopter path demoted to "when present") — over (a) materialize-in-adopter, because the mod header itself designates this repo the source (not an adopter), no sync-manifest exists to drift-check a materialized copy, and sibling canonical mods already follow the two-tier convention. Specified a twin-exists + qualifier-aware resolver as the regress-guard, scoped so it reds the reverse-recovery-audit class today, greens after the fix, and does not over-reach onto the out-of-scope missing-everywhere mods (architecture-canon, canonical-doc-sync) discovered during shaping and flagged for a follow-up todo.


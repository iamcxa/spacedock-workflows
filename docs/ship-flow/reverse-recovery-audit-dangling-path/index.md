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
pr:
---

ship-shape/SKILL.md:597 and ship-plan/SKILL.md:502 reference adopter-local
docs/ship-flow/_mods/reverse-recovery-audit.md which does not exist; the plugin-canonical
copy plugins/ship-flow/_mods/reverse-recovery-audit.md exists (3.7K). check-no-dangling.sh
misses this reference class. Small (S), non-UI, mechanical. This entity doubles as the live
single-entity proof for the L3 scheduler tick: after shape it must satisfy dual-key
eligibility (shaped + issue #69 labeled sd:approved) and be dispatched by the tick, not by hand.

## Acceptance criteria

**AC-1 — The referenced adopter-local path resolves.** Either the mod is materialized/synced at
docs/ship-flow/_mods/reverse-recovery-audit.md, or the two SKILL references are reconciled to the
canonical path — whichever shape judges the cheaper honest fix consistent with sync-manifest policy.
Verified by: the grep that today returns a dangling reference returns a resolving one.

**AC-2 — The reference class is mechanically regress-guarded.** check-no-dangling.sh (or an
equivalent wired CI check) fails on a fixture containing this class of dangling doc reference and
passes on the fixed tree.
Verified by: the check run red on a synthetic dangling fixture, green on the repo.

**AC-3 — Existing suite green.** The 110+ shell-test suite and CI gates pass unchanged.
Verified by: test suite run output.

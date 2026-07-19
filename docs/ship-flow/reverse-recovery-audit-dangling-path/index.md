---
title: Fix dangling reverse-recovery-audit adopter-local mod reference + regress-guard
status: execute
source: todo reverse-recovery-audit-dangling-path (pitch 5) + captain 票ok 2026-07-19 (L3 tick real-proof ticket)
started: 2026-07-19T02:37:40Z
completed:
verdict:
score:
worktree: .worktrees/spacedock-ensign-reverse-recovery-audit-dangling-path
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

## Stage Report: design

- DONE: Confirm trivial-pass eligibility — S mechanical (re-point 2 SKILL refs to plugin-canonical path + adopter 'when present' override per shape fix (b)); no schema/API/contract redesign. Emit minimal design.md + PROCEED, or escalate if a real contract delta surfaces.
  Trivial-pass PROCEED — additive-only, no `references/*.yaml`/CLI/template contract touched; design.md written with the eligibility table. No escalation-worthy contract delta; guard direction fully pre-shaped.
- DONE: Name exact contract deltas — the two SKILL reference lines (ship-shape SKILL.md:597, ship-plan SKILL.md:502) + the regress-guard code surface (twin-exists + qualifier-aware resolver in check-no-dangling.sh or wired CI).
  design.md §Contract deltas: Δ1 ship-shape:597, Δ2 ship-plan:502 (before/after intent), Δ3 additive resolver pass in `scripts/check-no-dangling.sh` (script is at scripts/, not lib/; resolve targets against REPO_ROOT).
- DONE: Name the test surfaces that must move — which of the 110+ shell tests assert the reference strings / dangling-check behavior.
  New `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` (CI-loop auto-discovered, ship-flow-invariants.yml:110); gate runs at ship-flow-invariants.yml:136. `grep -rl reverse-recovery-audit lib/__tests__/` = 0 hits → Δ1/Δ2 break none of the 120 tests.

### Summary

Trivial-pass PROCEED for an S mechanical ticket: two 1-line reference rewrites (Δ1/Δ2) plus one additive twin-exists+qualifier-aware resolver pass (Δ3) in `scripts/check-no-dangling.sh`. Exercising shape's guard against the real repo surfaced three load-bearing refinements the executer must not drop — (a) backtick-fenced scoping excludes `ship-flow-lint.md` JSON, (b) full-logical-unit unwrap excludes the soft-wrapped science-officer-em SKILL qualifier, and (c) the qualifier vocabulary must cover the agents-file "If the repo has … override" form, which is BEYOND shape's literal qualifier list and would otherwise false-positive `agents/science-officer-em.md:16-18` — plus the resolver must be drivable against a scratch root for the RED/GREEN fixtures. The design.md green-set table enumerates all eight `_mods` references proving only reverse-recovery-audit reds before the fix and nothing reds after (AC-2/AC-3).

## Stage Report: plan

- DONE: TDD contract for Δ3 resolver — RED-first. New plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh with fixtures: RED and 7 GREEN classes (fixed, qualified, wrapped-qualifier, no-twin, agents-override, json-noise, self-reference) plus green-on-real-repo-after-fix.
  plan.md T1 table (9 cases); fixture-drivability solved via main-guard (`[[ "${BASH_SOURCE[0]}" == "${0}" ]]`) + root-arg function `run_mislocated_canonical_mods "$root"`, sourced by the test post-T3.
- DONE: Atomic-commit task decomposition — order tests RED before impl GREEN. Task set T1 (RED test-only) → T2 (Δ1/Δ2 SKILL re-point) → T3 (Δ3 additive resolver → GREEN), each an independent commit with explicit pathspec.
  plan.md T1/T2/T3 sections; T2-before-T3 ordering is deliberate (no transient CI-red commit — the gate never goes live on an unfixed repo).
- DONE: Canonical Doc Actions — per root canonical doc (PRODUCT.md / ARCHITECTURE.md / ROADMAP.md) state update or explicit skip+rationale, naming the exact CI wiring proof.
  plan.md Canonical Doc Actions table: PRODUCT skip, ARCHITECTURE skip, ROADMAP update-deferred-to-ship (Later→Shipped); CI wiring proof cited as ship-flow-invariants.yml:110 (auto-discovery loop) + :136 (gate invocation, source_repo=='true').

### Summary

Wrote plan.md decomposing design's Δ1-Δ3 contract into 3 strictly-ordered atomic commits (T1 RED-only test authoring, T2 the two safe SKILL-ref rewrites, T3 the additive resolver pass), each with an explicit TDD contract and DC command. While exercising the resolver rule against the real repo (same method design used to find constraints a/b/c), found one additional load-bearing gap design's green-set table missed: `plugins/ship-flow/_mods/reverse-recovery-audit.md:9-10` itself contains a backtick-fenced, twin-present, adopter-absent, unqualified self-reference ("Adopting repos copy this to `docs/ship-flow/_mods/reverse-recovery-audit.md`…") that the stated conditions 1-3 alone would flag as a violation even after Δ1/Δ2/Δ3 land — recorded as constraint (d), a same-file self-reference exclusion, with its own fixture case (case 8) so AC-2's "green on the repo" claim is actually provable, not just asserted. Verified the 119 pre-existing `test-*.sh` files contain zero string assertions on the changed SKILL text (T2 breaks nothing) and confirmed the baseline `check-no-dangling.sh` run is currently green (8 patterns, blind to this class), giving a clean before/after comparison.


# Missing canonical mods — author or de-reference (both tiers) — Execute

Serial T1→T2→T3→T4→T5 per plan.md, single worktree, RED-first. Commits below are on
`spacedock-ensign/missing-canonical-mods`; each cites its observed RED/GREEN run.

## Task evidence

- **T1 — RED fixture suite (`cdc7852`).** Adds case 9 (RED, unqualified) + case 10 (GREEN,
  qualified) to `test-check-no-dangling.sh`; renames real-repo case 9 → 11. OBSERVED RED: 11/12
  PASS, case 9 FAIL (`expected exit 1, got 0`) — today's resolver still `continue`s on no-twin. No
  edits to `scripts/check-no-dangling.sh` in this commit.
- **T2 — REPO_ROOT precondition fix (`8822249`).** One-`..`-segment fix in
  `test-canonical-doc-sync-mod.sh` and `test-canonical-context-lifecycle.sh`. OBSERVED baseline
  RED: 0/14 and 0/10 (wrong directory). OBSERVED GREEN (post-fix, mod not yet authored): 5/14
  (Block 4 only) and 7/10.
- **T3 — author canonical-doc-sync.md (`590b1e6`).** New adopter-tier mod, content = the two
  tests' own assertion spec. OBSERVED GREEN: `test-canonical-doc-sync-mod.sh` 14/14 (was 5/14);
  `test-canonical-context-lifecycle.sh` 8/10 (was 7/10 — the `Silent omission` check flips).
- **T4 — de-reference architecture-canon + decisions-log (`785e391`).** 4 prose-only deletions
  (ship-shape:596, ship-plan:501, migrate-debrief template:33, INVARIANTS.md:199). AC-1 grep proof:
  `grep -rn 'architecture-canon\|decisions-log'` across all four files → 0 hits. No test pins this
  text (`grep -rl` over `lib/__tests__/` → 0 hits) — zero regressions.
- **T5 — classify-by-twin branch (`5a08112`).** Extends `run_mislocated_canonical_mods()` with a
  `missing-everywhere-canonical-mod` label (adopter absent AND twin absent, guarded to only fire
  when the adopter tree exists) + `--exclude-dir=__tests__` on this resolver's own grep. OBSERVED
  GREEN: `test-check-no-dangling.sh` 12/12 PASS (case 9 flips); `check-no-dangling.sh --self-test`
  and normal run both PASS, 8 patterns, exit 0.

## Deviation from plan.md (one-line rationale)

Fixed a pre-existing, unrelated C15 artifact-verbosity failure on this entity's own `plan.md` (405
lines, cap 200) — present since the plan-stage commit, verified via `git show
<dispatch-commit>:.../plan.md | wc -l` = 405, before any T1-T5 work. Applied the invariant's own
prescribed remedy (balanced `<details>` collapse of raw evidence, content trimmed only where
narratively redundant), same pattern `reverse-recovery-audit-dangling-path/execute.md` used for the
identical gate — necessary because `check-invariants.sh` must be green at execute handoff. Separate
commit (`91d4231`), not folded into T1-T5.

## Full local gate run (post-T5 + plan.md fix, final state)

- 129-file standalone shell suite (`plugins/ship-flow/lib/__tests__/test-*.sh`): **129/129 PASS**
  (run in 3 bounded batches; one apparent failure, `test-merged-pr-closeout-reconciler.sh`, was a
  90s-per-file timeout false-alarm — confirmed 198/198 PASS at 240s).
- Dogfood integration tier: `test-canonical-doc-sync-mod.sh` **14/14 PASS**;
  `test-canonical-context-lifecycle.sh` **8/10 PASS** (2 residual, pre-existing
  `docs/ship-flow/README.md` wording-gap failures, out of this entity's 3 ACs — documented, not
  fixed, per the plan-stage ratified narrowed AC-3).
- `bash scripts/check-no-dangling.sh` (real repo): PASS, 8 patterns, exit 0.
- `bash scripts/check-no-dangling.sh --self-test`: PASS, exit 0.
- `bash plugins/ship-flow/bin/check-invariants.sh`: PASS, exit 0 (C15 OK after the `plan.md` fix;
  was FAIL before it).
- `bash scripts/check-version-triple.sh`: PASS, exit 0 (untouched).
- `git diff --check` (dispatch commit `f7c4117`..HEAD): clean, no whitespace errors.

## Acceptance criteria

- **AC-1**: `grep -rn 'architecture-canon\|decisions-log'` across ship-shape/SKILL.md,
  ship-plan/SKILL.md, INVARIANTS.md, migrate-debrief template → 0 hits (de-referenced). Adopter-tier
  `docs/ship-flow/_mods/canonical-doc-sync.md` authored and consumed by ship-review + both
  integration tests. PASS.
- **AC-2**: `test-check-no-dangling.sh` 12/12 PASS, including case 9
  (RED-missing-everywhere-unqualified, now correctly flagged) and case 11 (green-on-real-repo).
  `check-no-dangling.sh` (real repo) exits 0. PASS.
- **AC-3 (narrowed, plan-stage ratified)**: standalone tier 129/129; dogfood tier 14/14 + 8/10 (2
  residual documented, out of scope). PASS as scoped.

Commits: `cdc7852` (T1), `8822249` (T2), `590b1e6` (T3), `785e391` (T4), `5a08112` (T5), `91d4231`
(plan.md C15 fix).

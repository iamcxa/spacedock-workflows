# Fix dangling reverse-recovery-audit adopter-local mod reference + regress-guard — Execute

Serial T1→T2→T3 per plan.md, single worktree, RED-first. Commits below are on
`spacedock-ensign/reverse-recovery-audit-dangling-path`; each cites its
observed RED/GREEN run.

## Task evidence

- **T1 — RED fixture suite (`9ecde9b`).** New
  `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`, 9 fixture cases
  + 1 existence check. OBSERVED RED: 10/10 assertions FAIL, each with the
  legible reason `resolver function not yet defined` (existence check) or its
  uniform per-case skip message. Zero edits to `scripts/check-no-dangling.sh`
  in this commit.
- **T2 — Δ1/Δ2 SKILL re-point (`055a7d9`).** AC-1 grep proof: both
  `ship-shape/SKILL.md:597` and `ship-plan/SKILL.md:502` now lead with
  `plugins/ship-flow/_mods/reverse-recovery-audit.md` (plugin-canonical) and
  contain `when present`. Prose-only; `grep -rl reverse-recovery-audit
  lib/__tests__/` = 0 hits confirmed, so this commit breaks no existing test.
- **T3 — Δ3 resolver pass (`39e36d3`).** GREEN: 10/10 assertions PASS,
  including case 9 (`run_mislocated_canonical_mods "$REPO_ROOT"` against the
  real repo, zero violations). Real gate run: `bash
  scripts/check-no-dangling.sh` exit 0 (8 patterns); `--self-test` exit 0
  (pre-existing 8-pattern self-test unaffected). `shellcheck` clean on both
  the script and the test file.

## Deviations from plan.md (one-line rationales)

1. Scan regex uses `-E`, not the plan's literal `-P`: this dev machine's
   default `grep` (BSD/macOS) has no `-P`, and since the call site is `...
   2>/dev/null || true`, `grep -P` would silently return zero violations
   forever on any non-GNU-grep machine — a blind gate, worse than a crashing
   one. The pattern needs no lookaround, so `-E` (POSIX ERE) is a
   functionally-identical, portable substitute (verified byte-identical
   match behavior).
2. `<name>` extraction avoids `grep -oP` lookbehind for the same portability
   reason — done via bash parameter expansion (`${match#*_mods/}`, strip
   trailing backtick, strip `.md`) instead of a second `-P` grep.
3. Fixed a latent `grep -c`/`pipefail` bug in T1's own harness, only surfaced
   once T3 made a real zero-violation GREEN result exist (`grep -c` exits 1
   on a zero count even though it prints `0`; under `set -e` this silently
   killed the test after case 1). Folded into T3's commit — required to reach
   the GREEN state T3's own DC calls for.
4. Fixed a pre-existing, unrelated C15 artifact-verbosity failure on this
   entity's own `plan.md` (247 lines, cap 200) — present since the plan-stage
   commit, verified via `git show <dispatch-commit>:.../plan.md | wc -l` =
   247, before any T1/T2/T3 work. Applied the invariant's own prescribed
   remedy (balanced `<details>` collapse of raw evidence, content unchanged),
   the same pattern `l3-scheduler-tick/execute.md` used for the identical
   gate — necessary because check-invariants.sh must be green at execute
   handoff. Separate commit (`a94b23c`), not folded into T1/T2/T3.

## Full local gate run (post-T3, final state)

- 120-file shell suite (`plugins/ship-flow/lib/__tests__/test-*.sh`):
  **120/120 PASS.**
- `bash scripts/check-no-dangling.sh` (real repo, post-fix): PASS, 8
  patterns, exit 0 — AC-2's real-repo proof.
- `bash scripts/check-no-dangling.sh --self-test`: PASS, exit 0.
- `bash plugins/ship-flow/bin/check-invariants.sh`: PASS, exit 0 (C15 OK
  after the `plan.md` fix above; was FAIL before it).
- `bash scripts/check-version-triple.sh`: PASS, exit 0 (untouched).
- node tests: none — no `package.json` at repo root.
- `git diff --check` (dispatch commit..HEAD): clean, no whitespace errors.
- `shellcheck scripts/check-no-dangling.sh` and `shellcheck
  plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`: both clean (0
  findings; two inline `# shellcheck disable=` directives for verified false
  positives — SC2016 literal-backtick regex, SC2329 indirect-dispatch
  functions — matching the repo's existing `check-invariants.sh` convention).

## Acceptance criteria

- **AC-1**: `grep -n 'reverse-recovery-audit.md'
  plugins/ship-flow/skills/ship-shape/SKILL.md
  plugins/ship-flow/skills/ship-plan/SKILL.md` — both lines lead with
  `plugins/ship-flow/_mods/reverse-recovery-audit.md` and contain `when
  present`. PASS.
- **AC-2**: fixture case 1 (RED-unqualified, synthetic) — resolver exits 1,
  1 violation line. Fixture case 9 (green-on-real-repo-after-fix) — resolver
  exits 0 against the real `REPO_ROOT`. The real `bash
  scripts/check-no-dangling.sh` run also exits 0. All PASS.
- **AC-3**: 120/120 shell tests pass (119 pre-existing + 1 new); zero
  regressions from Δ1/Δ2/Δ3. PASS.

Commits: `9ecde9b` (T1), `055a7d9` (T2), `39e36d3` (T3), `a94b23c` (plan.md
C15 fix).

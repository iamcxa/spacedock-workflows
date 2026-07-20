# check-invariants-terminal-fix — Execute

## AC-2 Surfaced Findings

Measured by reverting `check-invariants.sh` to `HEAD~1` (fixture present, predicate still buggy) for
the "before" run, then restoring the committed fix for "after" — both under `CI=true`, per plan.md
Task 3. Commands and full logs: `/tmp/before.log`, `/tmp/after.log` (session-local; not committed).
Working tree confirmed clean after the revert/restore round-trip (`git status --short` empty).

**Exit code — flag before the table.** Design/plan expected exit 0 → 1. Measured: **exit 1 → 1**,
not 0 → 1. This entity's own `plan.md` is 220 lines against `check-invariants.sh`'s 200-line cap for
`plan.md` (Principle 8, C15 artifact-verbosity) — an orthogonal, pre-existing failure unrelated to the
terminal predicate, present identically in both the before and after runs. It already forced exit=1
before this fix landed, so the corpus run doesn't visibly "flip" on this tree even though the
predicate-driven finding set underneath it changes substantially (below). Per the execute budget note
(park findings beyond the roborev surfacing rather than expanding scope): **not fixed here** — flagged
for the FO/verify stage to route (trim plan.md or adjust the cap) as separate work.

**Terminal-predicate-driven diff** (the AC-2 surfacing this ticket is scoped to) matches design.md's
pre-measured expectation exactly:

| Entity | Check | Finding | Pre-existing? |
| --- | --- | --- | --- |
| roborev-migration-receipt-merge-semantics | section-tag-coverage (Principle 5a) | 25× `ERROR` orphan header (missing `<!-- section: -->` tags) | Yes — masked by terminal misclassification until this fix |
| roborev-migration-receipt-merge-semantics | pre-mortem-emitted (C1) | `FAIL` — missing `pre_mortem:` field | Yes — masked |
| roborev-migration-receipt-merge-semantics | pitch-assumptions (Principle 5c, WARN-only) | `WARN` — pattern=pitch but 0 critical assumptions | Yes — masked, non-blocking |
| 7-review-surface-shape-not-plan | pitch-assumptions (Principle 5c, WARN-only) | `WARN` — pattern=pitch but 0 critical assumptions | Yes — masked, non-blocking |
| shape-confirm-instance-awareness, 7-review-surface-shape-not-plan, check-invariants-terminal-fix, l3-scheduler-tick, reverse-recovery-audit-dangling-path | section-tag-coverage grandfather | 5× new `WARN` "pre-049 baseline (no section tags; grandfather skip)" | Yes — masked, non-blocking |

`structural-parity-dc` (:607) and `pol-probe-invoked` (:842) add nothing on this corpus — confirmed
(no new lines attributable to either check in the diff); matches design's prediction.

**Hard constraint honored:** no entity body was edited (no `pre_mortem:` added, no section tags added
to roborev or any other entity). The only source edit in this ticket is `check-invariants.sh:61`; the
only new files are the Task-1 fixture block and this `execute.md`.

## Task 4 — dual-env gate results

Scope note (load-bearing, per plan.md Task 4): "green" = the test suite + node tests, NOT the
real-corpus `check-invariants.sh` run — the corpus run's RED is the designed AC-2 outcome
(roborev's un-masked findings), not a regression.

**Env 1 (local, no CI flag):** shell suite 129 test files — 128 pass (DC-18a/b/c/d all OK), 1 fail
(diagnosed below); `node --test` 79/79 pass exit 0; `check-version-triple.sh` exit 0;
`check-no-dangling.sh` exit 0 (8 patterns).

**Env 2 (`CI=true`, mirrors ship-flow-invariants.yml):** shell suite 129 files — 127 pass (DC-18
all OK), 2 exceptions (below); `node --test` 79/79 pass exit 0; corpus
`CI=true check-invariants.sh` exit 1 = FAIL C1 (roborev, the designed AC-2 outcome) + FAIL C15
(pre-existing plan.md length, above).

Both exceptions diagnosed, neither is a predicate regression:

1. `test-archived-corpus-invariants.sh` exit 1 (both envs) — the test embeds a full-corpus
   `check-invariants` run and asserts exit 0 (`corpus-invariants-pass`). Probe at the pre-fix
   dispatch commit (both changed files reverted to `6c36dd1`, run, restored, tree clean): already
   exit 1 there, driven solely by pre-existing C15. Post-fix it additionally carries the designed
   roborev C1 — the AC-2 corpus-RED propagating into the one suite test that asserts corpus green.
   Expected end-state per design ("verify/CI RED here is the expected end-state"); parked, not fixed.
2. `test-merged-pr-closeout-reconciler.sh` exit 124 in Env 2 only — killed by the CI-mirrored
   `timeout 90` on this machine; solo untimed run passes 198/198 in 3m05s, output streams only
   PASSes before the kill. Machine-speed artifact of mirroring CI's per-test timeout locally, not a
   test failure; unrelated to the predicate (0 terminal-predicate references in that test).

`git diff --check` clean before the final commit.

## Task log

- Task 1 (RED fixture): commit `3ddd2c2` — DC-18a/b/c FAIL, DC-18d OK (bug reproduced, control holds).
- Task 2 (predicate fix): commit `5f5ae69` — DC-18a/b/c/d all OK; full `test-check-invariants.sh` 66
  OK / 0 FAIL, exit 0.
- Task 3 (this file): before/after diff measured and restored; documented above.
- Task 4 (dual-env gate): results above — suite green both envs modulo the two diagnosed exceptions;
  corpus RED is the designed AC-2 outcome.

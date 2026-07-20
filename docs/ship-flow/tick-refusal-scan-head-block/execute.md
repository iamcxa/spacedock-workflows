# Fix tick refusal scanning head-block — Execute

Five atomic, serially-committed TDD tasks per plan.md, one worktree
(`spacedock-ensign/tick-refusal-scan-head-block`), RED-before-GREEN per
code-bearing task.

## Task evidence

- **Task 1 — AC-1/AC-2/AC-3 two-phase batch-emit + reason-scoped dedup
  (`193196f`).** RED: new `test-ship-flow-scheduler-refusal-batch.sh`'s 4
  cases reproduced failing against the unmodified scheduler — AC-1 emitted
  only 1 of 3 refusals (the head-block), AC-3 emitted 0 refusals + an
  immediate dispatch (the sharpest disproof: `eligible-entity` sorts
  alphabetically first, so the old code's `return 0` on the first case-0 hit
  fired before either refusing entity was ever scanned), AC-2 re-emitted the
  identical refusal on ticks 2/3 instead of deduping (the literal finale
  spam). GREEN: broadened `entity_in_backoff` to an optional
  `(match-event, match-reason)` signature and rewrote Precedence-2 as
  two-phase collect-then-act (design.md §3) — 23/23 new-file assertions
  pass. Regression canaries: fullcycle 8/8 (leg 3 still dispatches the
  child — the post-eval, case-1|2-only dedup disproof holds), eligibility
  34/34, backoff 8/8.
- **Task 2 — rollup `interventions` per-line pin (`d7a117d`).** No code
  change (DC-1: rollup awk untouched). New fixture
  (`events-multi-refusal-beat.jsonl`, two `refusal` lines sharing one
  `tick_id` + one `blocked` line) + `run_multi_refusal_beat_intervention_count_case`
  asserts `interventions (blocked + refusal): 3` against the CURRENT,
  unmodified `cmd_rollup` — 10/10 rollup-suite pass, confirming the
  semantics were already per-line as design.md §2 claimed.
- **Task 3 — contract-text delta, Note 1 (`021b0e1`).** Prose-only: header
  `:4-11`, AC-3b comment `:558-560` (cited contract name only —
  "exactly-one-event-per-tick" → "one-primary-event-per-action"; the
  DECISION it justifies is unchanged), `RUNBOOK.md:24-25`. No RED/GREEN
  pair (design.md §4: no existing assertion pins this text as a line
  count). `git diff` on the two files showed only these 3 edits; full
  9-file scheduler suite re-run green, proving zero behavior change.
- **Task 4 — INVARIANTS Principle 18 + check-invariants.sh C18
  (`62c83fb`).** RED: `--check refusal-observability-record` →
  `ERROR: unknown check` (exit 2). GREEN: Principle 18 (mirrors Principle
  17/C16's Rule/Failure-mode/Grep-check/Source structure, folds
  contract-revision Note 2) + Revision History v1.6.0 bump;
  `check_refusal_observability_record()` wired into the `--check` dispatch
  table + full-run sweep. `--check refusal-observability-record` → exit 0,
  `OK C18 ...`; full `check-invariants.sh` (C1-C18) → exit 0.
- **Task 5 — Canonical Doc Actions (`bad7db7`).** ROADMAP.md Now-row add.
  `git diff` shows only the added row; `check-no-dangling.sh` +
  `check-version-triple.sh` both pass.

## Deviations from plan.md

1. **Task 4 commit also fixes a self-inflicted C15 artifact-verbosity
   violation on plan.md** (241 body / 442 raw lines, cap 200/400) — the
   same class of gate failure tick-hardening's execute.md deviation #1 hit
   and fixed identically: GREEN excerpts that now duplicate the actual
   committed diffs (Task 1's Precedence-2 rewrite, Task 4's
   check-invariants.sh wiring) were shortened to pointers; verbose
   reference sections (Terminal DCs commands, the note/delta-site table,
   the cut-list) were folded into `<details>`. No task content, decisions,
   or DCs changed — re-confirmed via full 9-file suite + `check-invariants.sh`
   green after the edit.
2. **Task 5: no Later-row removal** — plan.md's literal instruction was
   "move row 40 from Later → Now", but this worktree's ROADMAP.md carries
   no Later row for this entity at all. plan.md's own Summary already
   names the reason: `decisions.md` (and the row-40 numbering shape.md
   cites) lives only on `iamcxa/muscat-v1`, a separate, more-advanced state
   track this origin/main-based worktree predates. Added directly to Now;
   nothing to remove.

## Full local gate (pre-handoff self-check)

<details>
<summary>Gate run outputs</summary>

- Scheduler set, NORMAL env (9 files: backoff, eligibility, fullcycle,
  idempotence, plist, reconcile, report, rollup, NEW refusal-batch): all
  exit 0 — 8/8, 34/34, 8/8, 11/11, 11/11, 16/16, 10/10, 10/10, 23/23.
- `bash plugins/ship-flow/bin/check-invariants.sh` (full, C1-C18) → exit 0,
  all OK including the new `OK C18 refusal-observability-record`.
- `bash scripts/check-no-dangling.sh` → PASS (8 patterns).
- `bash scripts/check-version-triple.sh` → PASS (0.9.0 triple).
- `bash -n` on both touched `.sh` files → syntax OK.
- CI-sim spot-check (`env -i PATH=/usr/bin:/bin HOME="$HOME" CI=true bash
  <test>`, no git identity, no `claude`/`spacedock`/`gh` on PATH): the two
  files this entity actually touches for test coverage —
  `test-ship-flow-scheduler-refusal-batch.sh` (23/23) and
  `test-ship-flow-scheduler-rollup.sh` (10/10) — pass identically to
  normal env. `bash 3.2.57` (macOS system bash, resolved via this minimal
  PATH) throws `unbound variable` on bare `"${arr[@]}"` expansion of an
  EMPTY array under `set -u` — verified this does NOT affect Task 1's
  Precedence-2 rewrite, which only ever expands `"${!refusal_slugs[@]}"`
  (indices, safe when empty) and `${#refusal_slugs[@]}` (length, safe when
  empty), never a bare `"${refusal_slugs[@]}"`.
- CI-sim on the 3 Precedence-1-exercising files this entity did NOT touch
  (backoff, fullcycle, reconcile) shows pre-existing failures/blank output
  unrelated to this diff — traced to `merged-pr-closeout-reconciler.sh:264`
  (`command -v gh || reject_input missing-gh`) failing closed when `gh` CLI
  is absent from the minimal PATH. Confirmed pre-existing: `git diff
  origin/main` on both `test-ship-flow-scheduler-backoff.sh` and
  `merged-pr-closeout-reconciler.sh` is empty (neither file is touched by
  this entity), and both pass 8/8 and 16/16 in NORMAL env. The Terminal DCs'
  full dual-env sweep across all ~15 other test files is plan.md's own
  explicitly verify-stage scope, not an execute-stage task — flagged here
  as a finding, not fixed.

</details>

## Gate-brief (for the verify-stage SO-EM + codex panel)

Per plan.md's "Verify-gate handoff" section, this brief is a worker
deliverable the FO forwards verbatim; the FO does not compose it.

- **Task 1 mechanism diff:** `ship-flow-scheduler.sh` — `entity_in_backoff`
  (broadened to optional `(match-event, match-reason)`, backward-compatible
  defaults) + Precedence-2 rewritten from a single-`return`, first-refusal-
  only loop into two-phase collect-then-act (Phase 1 scans every entity,
  no side effects; Phase 2 emits all queued refusals in scan order, then
  the beat's one primary action). Commit `193196f`.
- **Test evidence:** every DC in plan.md Tasks 1-5 green (see Task
  evidence above); full 9-file scheduler suite green in NORMAL env;
  `check-invariants.sh` (C1-C18) green; `check-no-dangling.sh` +
  `check-version-triple.sh` green. CI-sim spot-check on this entity's own
  new/touched test files (refusal-batch, rollup) green; a pre-existing,
  diff-unrelated `gh`-CLI-absence gap on 3 untouched Precedence-1 test
  files is named above, not fixed (out of this entity's scope).
- **Execute-stage hard conditions' resolution:** INVARIANTS.md Principle
  18 (Rule/Failure-mode/Grep-check/Source, mirrors Principle 17's
  structure) landed in commit `62c83fb`, verified via
  `check-invariants.sh --check refusal-observability-record` → `OK C18`.
  RUNBOOK.md:24-25 wording landed in commit `021b0e1`, verified via
  targeted `git diff` (prose-only, 3 sites, no behavior change).
- **Residual risk:** none identified beyond the two named deviations above
  (both formatting/scope-boundary, not mechanism). Task 1's GREEN matches
  design.md §3's pseudocode exactly — no divergence to flag.

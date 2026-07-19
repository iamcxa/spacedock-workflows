# Tick hardening — Execute

Nine atomic, serially-committed TDD tasks per plan.md, one worktree
(`spacedock-ensign/tick-hardening`), RED-before-GREEN per task.

## Task evidence

- **Task 1 — AC-1a `--tick-id` (`eb910b6`).** RED: `run_tick_id_marker_case`
  fails exit 2 (unrecognized arg). GREEN: 15/15 adapter tests pass.
- **Task 2 — AC-1b `SHIP_PROMPT`/`--print-spawn` (`218b76a`).** RED: 5 new
  print-spawn assertions fail (exit 2). GREEN: 21/21 pass.
- **Task 3 — AC-1c thread tick_id (`94a9d34`).** RED:
  `run_tick_threads_tick_id_case` fails (empty `TICK_ID_SEEN=`). GREEN:
  23/23 pass; reconcile 16/16 + fullcycle 8/8 unaffected.
- **Task 4 — AC-2 launcher spawn + preflight (`250cfd7`).** RED: 4
  assertions fail (bare-claude `SPAWN_LINE`; spacedock-only PATH → exit 3).
  GREEN: 27/27 pass. Execute-time probe (per design.md's parked residual):
  real `spacedock claude "..." --plugin-dir <worktree>/plugins/ship-flow --
  -p --output-format text` → exit 0, replied `PROBE_OK`, confirming the
  plugin-checkout-root level.
- **Task 5 — AC-3a `derive_timeout_sec` (`45c028c`).** RED: 2 new cases
  fail (`"timeout_sec":9000`/`5400` absent). GREEN: 31/31 pass; full
  scheduler suite (7 files) green, no regression.
- **Task 6 — AC-3b checkpoint (`bcc0f07`).** RED: `checkpoint`/
  `resume_stage` assertions fail (key absent). GREEN: 33/33 pass;
  reconcile/fullcycle/eligibility unaffected.
- **Task 7 — AC-4 `entity_in_backoff` (`3f6491c`).** RED: NEW
  `test-ship-flow-scheduler-backoff.sh` case 1 (head-block) fails — the
  cited Wave-0 incident reproduced (eligible-entity never reached); case 2
  (window expiry) passes even pre-fix by design. GREEN: 8/8 new file pass;
  full scheduler suite (9 files) green.
- **Task 8 — AC-5 plist PATH (`574151e`).** RED:
  `@USER_LOCAL_BIN@` placeholder assertion fails (absent). GREEN: 11/11
  plist tests pass.
- **Task 9 — canonical docs (`64ae2f6`).** `git diff` on the three touched
  doc files shows only the named additions (verified via diff review, no
  unrelated edits); `check-no-dangling.sh` + `check-version-triple.sh` both
  pass.

## Deviations from plan.md

1. Extra unplanned fix commit (`9a28831`): `check-invariants.sh`'s C15
   artifact-verbosity gate failed on plan.md at 374 body lines (cap 200) —
   a real CI blocker on this branch's own committed plan.md, caught while
   running the three check-* scripts this stage's gate requires.
   Reformatted per-task RED/GREEN mechanics into `<details>` blocks
   (content preserved; a few GREEN excerpts that now duplicate the actual
   committed code were shortened to a pointer). No task content, decisions,
   or DCs changed. Precedented: `l3-scheduler-tick/execute.md` deviation
   #9 applied the identical fix for the identical reason.
2. ROADMAP.md Now-row uses `execute` (the entity's actual current
   `status:` frontmatter value) rather than plan.md's literal `plan` —
   plan.md's Task 9 instruction was written before this stage started and
   would already be one stage stale; the row's purpose is to reflect
   current reality, matching the other Now-row entries' pattern.

## Full local gate (pre-handoff self-check)

<details>
<summary>Gate run outputs (raw)</summary>

- Scheduler set, NORMAL env (9 files: adapter, NEW backoff, reconcile,
  fullcycle, eligibility, idempotence, plist, report, rollup): all exit 0,
  `All assertions passed` each (foreground re-run at handoff, exit codes
  recorded).
- CI-SIM env (`env -i PATH=<timeout-only>:/usr/bin:/bin HOME=<empty tmp>
  CI=true` — no git identity, no `claude`/`spacedock` on PATH) for the
  three CI-sensitive tests + the new backoff test: adapter 33/33, backoff
  8/8, reconcile 16/16, fullcycle 8/8 — all exit 0.
- Full shell suite sweep (`CI=true timeout 90 bash` per file, 130 files):
  129/130 pass within the CI cap; `test-merged-pr-closeout-reconciler.sh`
  exceeds 90s wall-clock on this machine only — re-run at 300s → exit 0,
  198/198 assertions (file untouched by this diff; local-hardware
  wall-clock artifact, not a failure).
- `node --test plugins/ship-flow/bin/*.test.mjs` → 79/79 pass, exit 0.
- `CI=true bash plugins/ship-flow/bin/check-invariants.sh` → exit 0, all OK
  (including C15 after the plan.md fix).
- `bash scripts/check-no-dangling.sh` → PASS (8 patterns).
- `bash scripts/check-version-triple.sh` → PASS (0.9.0 triple).
- `shellcheck` (v0.11.0) on all 6 changed `.sh` files
  (ship-flow-scheduler.sh, scheduler-runner-adapter.sh,
  stub-runner-echo-tick-id.sh, test-scheduler-runner-adapter.sh,
  test-ship-flow-scheduler-backoff.sh, test-ship-flow-scheduler-plist.sh)
  → zero findings.
- `git diff --check origin/main...HEAD` → clean after the stage-report
  append to index.md (the only prior hit was a trailing blank line at
  index.md EOF, occupied by the appended report).

</details>

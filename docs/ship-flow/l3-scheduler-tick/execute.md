# L3 scheduler tick — Execute

Serial T0→T7 per plan.md, single worktree, RED-first. Commits below are on
`spacedock-ensign/l3-scheduler-tick`; each cites its observed RED/GREEN run.

## Task evidence

- **T0 — go/no-go (no commit).** `gh auth status` / `spacedock --version` /
  `command -v claude` / `command -v codex` all exit 0. Controller worktree
  created: `.worktrees/ship-flow-scheduler-controller` (branch
  `ship-flow-scheduler-controller` off origin/main). Sentinel proof:
  `timeout 60 claude -p` one-shot from the controller worktree → exit 0,
  stdout exactly `SENTINEL_OK`. GO.
- **T1 — RED fixture suite (354fb88).** 8 test files + fixtures. OBSERVED RED:
  all 8 exit 1, each with `FAIL: helper exists and is executable (…)` as the
  sole failure — recorded before any implementation commit.
- **T2 — tick CLI core (94f2571).** GREEN: idempotence 11/11, eligibility
  22/22. shellcheck clean.
- **T3 — runner adapter (20c6a0b).** GREEN: runner-adapter 13/13. Real spawn
  DC-2: adapter run against real `claude -p` from the controller worktree →
  one JSON line, `exit_class=timeout`, receipt file exists on disk.
- **T4 — gate report (ef2d837).** GREEN: report 10/10 (static no-write grep
  gate + runtime `git status --porcelain` empty).
- **T5 — reconcile + advance (1cd8b1d).** GREEN: reconcile 11/11, fullcycle
  6/6; regression idempotence/eligibility/adapter/report all green;
  `git diff --stat` on reconciler + dag-waves empty (composed primitives
  untouched).
- **T6 — launchd + rollup + RUNBOOK (dd8c5f5).** GREEN: rollup 8/8 (byte-
  identical double run), plist 10/10 (`plutil -lint` OK both templates).
  RUNBOOK.md present.
- **T7 — terminal proofs.** DC-1 (fixture full-cycle) GREEN: fullcycle 6/6 —
  dispatch → merged → reconcile → next-ready. DC-2 (LIVE proof on issue #69)
  is FO-owned at H7 from the project root per the dispatch checklist — not
  run from inside execute.

## Deviations from plan.md (one-line rationales)

1. Added `--gh-provider gh|fixture --gh-fixture-dir` tick/report flags (not in
   design §1): eligibility/projection reads need their own hermetic CI seam;
   mirrors the reconciler's existing `--pr-provider` convention.
2. DoR narrowed to one gate (`shape.md` exists non-empty → `dor-stale-shape`):
   design left DoR mechanics undefined; finer dor-* codes stay reserved.
3. `is_shaped` is an explicit whitelist (shape…ship): `draft` must not pass
   (plan's own #69 precondition), unknown statuses fail closed per AC-2.
4. Reconcile precedence fires on any non-OPEN PR state, not just MERGED:
   CLOSED/UNKNOWN must reach the reconciler so PROMPT_CAPTAIN → blocked.
5. `advance` feeds dag-waves via documented `--stdin` with a tick-built TSV
   (active + `_archive` rows) instead of `--from-workflow`: that mode cannot
   see `_archive/`, so a just-reconciled parent's done row is missing and the
   child's depends-on fails the fail-closed closure check (exit 3).
6. Reconciler outcomes other than PROCEED/PROMPT_CAPTAIN (REJECT/crash) →
   terminal `blocked` (`reconciler-error`): a crashed reconciler is never a
   successful reconcile.
7. T2's commit already carries the reconcile/advance/adapter-call code paths
   (shared control flow); each path counted done only when its own test went
   green in T3/T5.
8. Fixture children carry `status: draft`, not empty: dag-waves' awk default
   field splitting collapses an empty TSV status column into the deps column.
9. plan.md wrapped its T0–T7 detail in one `<details>` block (content
   unchanged): C15 artifact-verbosity caps plan.md body at 200 lines; the fix
   is the invariant's own prescribed remedy, applied here because the gate
   must be green at execute handoff.
10. Report renders `awaiting_merge`/`merged` rows only; `running`/`blocked`
    need lease/receipt inputs the design §7 CLI signature doesn't take;
    `gh_checks`/`cross_model` are `n/a` pending a pinned artifact-read
    contract.

## Full local gate (pre-handoff self-check)

- Shell suite: full `lib/__tests__/test-*.sh` loop — see Stage Report for the
  final counts (run after the last tree change).
- Node: `node --test plugins/ship-flow/bin/*.test.mjs` → 79/79 pass.
- `CI=true bash plugins/ship-flow/bin/check-invariants.sh` → exit 0 (18 OK; 2
  pre-existing grandfathered WARNs untouched).
- `bash scripts/check-no-dangling.sh` → PASS; `bash
  scripts/check-version-triple.sh` → PASS; `git diff --check` → clean.

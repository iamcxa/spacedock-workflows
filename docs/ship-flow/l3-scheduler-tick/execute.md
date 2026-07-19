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
   CLOSED must reach the reconciler so PROMPT_CAPTAIN → blocked. **Superseded
   by feedback cycle 1, F4:** UNKNOWN no longer reaches the reconciler — see
   "Feedback Cycle 1 fixes" below.
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

## Feedback Cycle 1 fixes

Verify VETO'd with 3 BLOCKING + 1 WARNING (codex cross-model challenge,
citation-verified). Each finding: RED fixture committed first (observed
failing), then the fix, then the green run — no fix commit precedes its own
RED commit.

- **F1 (BLOCKING, AC-1) — dedup on live worktree/PR, not frontmatter alone.**
  RED `825bf62`: two new fixtures model a crash after the real worktree/PR was
  created but before the frontmatter write (both fields empty); 4/28
  eligibility assertions failed (dispatch fired instead of refusing). Fix
  `11d4ce0`: `evaluate_entity` now also checks a live directory at
  `<controller-worktree>/.worktrees/spacedock-ensign-<slug>`, and a new
  `pr_exists_for_slug()` does a live gh lookup by conventional branch
  (fail-closed on `UNKNOWN`). GREEN: eligibility 28/28; full scheduler suite
  unaffected.
- **F2 (BLOCKING, concurrency=1) — liveness-only reclaim + ownership token.**
  RED `a61cbd8`: new unit suite `test-scheduler-lease.sh` sourcing
  `scheduler-lease.sh` directly; a stale-but-alive holder (age > timeout, pid
  alive) got reclaimed, and release had no token param at all (crashed on
  unbound `SCHEDULER_LEASE_TOKEN`). Fix `c8b70e6`: `scheduler_lease_acquire`
  reclaims ONLY on a provably-dead pid (age is no longer an independent
  trigger); `scheduler_lease_release` refuses unless its token matches the
  record's; the previously-unbounded `merged-pr-closeout-reconciler.sh`
  invocation is now wrapped in `timeout <max_run_timeout>`, so an overrunning
  holder is forcibly ended and reclaims via the same dead-pid path.
  design.md §5 and RUNBOOK.md updated to match. GREEN: scheduler-lease 7/7.
- **F3 (BLOCKING, AC-5) — fullcycle leg 3 proves a real dispatch, not just a
  label.** RED `abbe540`: a new leg 3 (third tick, after the parent is
  archived) asserted a `dispatch` event for the child — failed, since the
  child fixture was `status: draft` (fails `is_shaped()`), so it stayed
  ineligible no matter what. Fix `b2dbb66`: the test now promotes the child to
  genuinely `status: shape` + `sd:approved` (+ `shape.md`) between leg 2 and
  leg 3, modeling the real "shape it, approve the issue" step. **No production
  code changed** — the existing dispatch-precedence scan already correctly
  dispatches any genuinely-eligible entity; the gap was purely that the prior
  fixture could never reach that state. GREEN: fullcycle 8/8.
- **F4 (WARNING) — UNKNOWN gh state warns and no-ops, never escalates.** RED
  `22e1145`: new fixture (`pr:` set, gh state UNKNOWN via `--pr-fixture`) —
  the tick funneled it into `run_reconcile_action` like a real CLOSED state,
  emitting `blocked`/`reconciler-prompt-captain`. Fix `cf83300`: the
  precedence-1 loop now short-circuits on `pr_state=UNKNOWN` with a
  `no-op reason=gh-state-unknown` event before ever invoking the reconciler;
  nothing is mutated, so the next tick just re-derives and retries. design.md
  §2's no-op reason vocabulary extended. GREEN: reconcile 16/16.

## Full local gate (pre-handoff self-check)

- Shell suite: full `lib/__tests__/test-*.sh` loop (119 files, `CI=true
  timeout 90 bash` per file, matching `.github/workflows/ship-flow-invariants.yml`)
  → 118/119 files pass. The one failure
  (`test-archived-corpus-invariants.sh`) is **pre-existing and out of this
  stage's scope** — see below.
- Node: `node --test plugins/ship-flow/bin/*.test.mjs` → 79/79 pass.
- `bash scripts/check-no-dangling.sh` → PASS; `bash
  scripts/check-version-triple.sh` → PASS; `git diff --check` → clean.
- `CI=true bash plugins/ship-flow/bin/check-invariants.sh` → **exit 1**: 15 OK,
  2 pre-existing grandfathered WARNs (unchanged), **4 FAIL** (C11, C12, C14,
  C15 — new since the prior execute/verify reports' "exit 0" claims). This is
  the SAME failure set independently reproduced at
  `test-archived-corpus-invariants.sh`.
  **Verified pre-existing**, not introduced by this feedback cycle's work: re-run
  identically at commit `0a053ec` (the FO's dispatch commit for feedback
  cycle 1, i.e. the exact tree state handed to this ensign before any of the
  F1–F4 commits above) in an isolated detached worktree — same 4 FAILs, byte
  identical. Root causes are both outside this stage's authority to fix:
  - C11/C12/C15 need edits to `l3-scheduler-tick/verify.md` (missing `##
    Panel Coverage` / `## Deferred to TODO` sections, 276 lines vs. the
    120-line cap) — this dispatch's own instructions say "Do not touch
    verify.md."
  - C14 flags the FO's own dispatch commit `0a053ec7` ("entering execute
    (feedback cycle 1)") for malformed stage-entry grammar — not a commit
    this ensign authored or should rewrite.
  Flagging to the FO/captain rather than silently declaring the gate green or
  unilaterally editing verify.md/rewriting a commit outside this stage's
  remit.

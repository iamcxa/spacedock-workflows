<!-- section:ship-report -->
# Tick hardening — delegation marker, launcher spawn, time-budget, blocked-backoff — Ship

Hardens the L3 scheduler tick's spawn seam: mechanical delegation marker retiring the
`decisions.md` 30-min-receipt workaround, launcher-spawn via the verified spacedock `-p`
passthrough, appetite-scaled timeout with a resumable checkpoint, and blocked-backoff so
one stuck entity no longer head-blocks the whole queue — the four failure classes that
surfaced live during tonight's Wave-0 launchd bring-up (issue #74).

PR: https://github.com/iamcxa/spacedock-workflows/pull/81 — body composed once to a file
from shape/verify/execute canonical artifacts (Problem incl. the two Wave-0 findings,
verify cycle-2 per-AC evidence incl. the re-blocked injection PoC, execute commits across
both cycles), privacy grep 0 hits, `doc-impact-gate.sh` waiver declared + PASS locally,
pushed, `gh pr view 81` confirmed `mergeable=MERGEABLE` (`mergeStateStatus=BLOCKED` only
on the still-`IN_PROGRESS` `invariants` check; `doc_impact` + GitGuardian already
`SUCCESS`) before `pr: "#81"` was written via `persist-pr-metadata.sh`
(`verdict=OK reason=written`, number- and body-confirmed). Auto-merge lane armed (granted
at the verify gate): `gh pr merge 81 --auto --merge` succeeded,
`autoMergeRequest.mergeMethod=MERGE` confirmed; required checks will execute the merge —
not awaited here.

**Housekeeping note**: this ship stage found the worktree branch 34 ahead / 30 behind
`origin/main`, including 3 stray cross-entity archive commits (auto-fix SessionStart
hook, unrelated to this entity). Rebased them out (`rebase --onto`) before push to keep
the PR diff scoped to this entity's own 6 ACs; verified zero later commit touched an
`_archive/` path and re-ran the full local gate green post-rebase.

## Todo Closeout Digest

- Deferred (verify.md, stand): W2 `entity_in_backoff` slug-as-BRE hardening (not
  triggered by any real slug); W3 `timeout` lacking `--kill-after` (pre-existing
  repo-wide adapter pattern, blast radius raised by the 900→5400s default bump).
- Cross-branch, FO-owned (plan.md cut-list, unchanged): ROADMAP.md Later-row fold for
  `scheduler-tick-delegation-marker` + `pipeline-timeout-checkpoint-event`, and the
  `decisions.md` 30-min-receipt clause removal — both live only on `iamcxa/muscat-v1`.
- Not captured as a todo (plan.md cut-list): AC-4 precedence-2 dispatch-repeat test
  coverage — implemented, not independently RED-tested this round; no cited live
  incident makes it non-blocking.
- Named follow-up candidate — **controller freshness step**: a periodic
  rebase-onto-main (or equivalent freshness check) for long-lived stage worktrees would
  prevent the cross-entity commit bleed-through this ship stage had to surgically
  rebase away.
- Named follow-up candidate — **ensign foreground-gate discipline**: verify.md's
  FOREGROUND-only, ≤600s-bounded, sequential re-run pattern for independent
  verification works well but lives ad hoc in stage prose; worth promoting into the
  ensign shared-core reference as a named, reusable convention.

## Canonical Docs Update

Per plan.md Task 9, already committed in execute (cite, not redo): `64ae2f6` —
`docs/ship-flow/l3-scheduler-tick/design.md` (§2 checkpoint field, §6 adapter interface
note) + `RUNBOOK.md` (resume-from-checkpoint + delegation-marker retirement notes) +
`ROADMAP.md` Now-row add. ARCHITECTURE.md / INVARIANTS.md / PRODUCT.md / README.md all
scoped SKIP per plan.md's table (no durable-architecture / value-prop / end-user-surface
change in this hardening pass).

### Token + Release

Token: not tracked (no `token_budget`/`token_actual` stamped on this entity). Version:
no plugin version bump this ship — same-surface hardening on the already-shipped L3
tick, not a new capability; repo convention batches bumps into separate
`chore(ship-flow): release X.Y.Z` commits.

### Verdict

status: auto-merge-armed
pr: "#81"
tasks: 9/9 (plan.md, cycle 1) + 3/3 bounce fixes (cycle 2)
verify: PASS (PROCEED) — verify.md cycle 2, independent re-run, injection PoC re-blocked
  firsthand
dependency: hackathon-2 Wave 1 (issue #74); merge unblocks the live W2a tick-dispatch
  finale (FO-owned, post-merge)

<!-- /section:ship-report -->

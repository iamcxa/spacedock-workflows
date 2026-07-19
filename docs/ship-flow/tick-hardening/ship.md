<!-- section:ship-report -->
# Tick hardening — delegation marker, launcher spawn, time-budget, blocked-backoff — Ship

Hardens the L3 scheduler tick's spawn seam: delegation marker (retires the
`decisions.md` 30-min-receipt workaround), launcher-spawn via the verified spacedock
`-p` passthrough, appetite-scaled timeout + resumable checkpoint, and blocked-backoff
so one stuck entity no longer head-blocks the queue — the four failure classes from
tonight's Wave-0 launchd bring-up (issue #74).

PR: https://github.com/iamcxa/spacedock-workflows/pull/81 — body composed once from
shape/verify/execute artifacts (Problem incl. the two Wave-0 findings, verify cycle-2
per-AC evidence incl. the re-blocked injection PoC, commits across both cycles);
privacy grep 0 hits; `doc-impact-gate.sh` waiver declared, PASS locally; pushed.
`gh pr view 81`: `mergeable=MERGEABLE` (`mergeStateStatus=BLOCKED` only on the
still-`IN_PROGRESS` `invariants` check; `doc_impact`/GitGuardian already `SUCCESS`).
`pr: "#81"` written via `persist-pr-metadata.sh` (`verdict=OK reason=written`,
number+body confirmed). Auto-merge armed (granted at verify gate): `gh pr merge 81
--auto --merge` succeeded, `mergeMethod=MERGE` confirmed; checks execute the merge,
not awaited here.

Housekeeping: branch was 34 ahead / 30 behind `origin/main`, carrying 3 stray
cross-entity archive commits (SessionStart hook, unrelated). Rebased them out
(`rebase --onto`) to keep the PR scoped to this entity's 6 ACs; confirmed no later
commit touched `_archive/`; full local gate re-ran green post-rebase.

## Todo Closeout Digest

- Deferred (verify.md): W2 `entity_in_backoff` slug-as-BRE (no real slug triggers
  it); W3 `timeout` lacking `--kill-after` (pre-existing pattern, blast radius up
  from the 900→5400s default bump).
- Cross-branch, FO-owned (plan.md cut-list): ROADMAP.md Later-row fold for the two
  merged todos + `decisions.md` clause removal — both on `iamcxa/muscat-v1` only.
- Cut-list, not a todo: AC-4 precedence-2 dispatch-repeat coverage — implemented,
  untested this round, no cited live incident.
- Follow-up candidate — **controller freshness step**: a periodic rebase-onto-main
  for long-lived stage worktrees would prevent the cross-entity bleed-through this
  stage had to rebase away by hand.
- Follow-up candidate — **ensign foreground-gate discipline**: verify.md's
  FOREGROUND-only, ≤600s-bounded re-run pattern works but lives ad hoc in stage
  prose; worth a named place in the ensign shared-core reference.

## Canonical Docs Update

Task 9, already committed in execute (cite, not redo): `64ae2f6` —
`l3-scheduler-tick/design.md` (§2/§6) + `RUNBOOK.md` + `ROADMAP.md` Now-row.
ARCHITECTURE/INVARIANTS/PRODUCT/README all SKIP per plan.md's table (no durable
architecture/value/end-user-surface change this pass).

### Token + Release

Token: not tracked (no budget/actual stamped). Version: no bump — same-surface
hardening, not a new capability; bumps land in separate release commits.

### Verdict

status: auto-merge-armed
pr: "#81"
tasks: 9/9 (cycle 1) + 3/3 bounce fixes (cycle 2)
verify: PASS (PROCEED) — cycle 2, independent re-run, injection PoC re-blocked
  firsthand
dependency: hackathon-2 Wave 1 (#74); merge unblocks the live W2a tick-dispatch
  finale (FO-owned, post-merge)

<!-- /section:ship-report -->

# Fix tick refusal scanning head-block — Verify

Independent re-run against `execute.md` (5 tasks landed on
`spacedock-ensign/tick-refusal-scan-head-block`, PR #91 open,
`72ccc81`). All decisive suites re-run fresh in this worktree (not taken
on the worker's self-report). Cross-model (codex) coverage is FO-owned,
running in parallel — not included here per dispatch instruction.

## Independent Quality Gate Re-Run

- `test-ship-flow-scheduler-refusal-batch.sh`: **23/23 PASS** (fresh
  run).
- `test-ship-flow-scheduler-fullcycle.sh`: **8/8 PASS** (fresh run) —
  leg 3 still dispatches the child; the post-eval, case-1|2-only dedup
  disproof holds.
- `check-invariants.sh` full run (C1-C18): **exit 0**, `OK C18
  refusal-observability-record` present. Targeted `--check
  refusal-observability-record` and `--check artifact-verbosity` both
  independently re-run: **exit 0** each.
- gh-CLI-absence gap (execute-stage finding) reproduced firsthand: `env
  -i PATH=/usr/bin:/bin HOME="$HOME" CI=true bash
  test-ship-flow-scheduler-backoff.sh` → 7/8, one FAIL
  (`source=reconciler-prompt-captain` missing — `gh` absent from the
  minimal PATH causes `merged-pr-closeout-reconciler.sh:264`'s `command
  -v gh || reject_input missing-gh` to fail closed). NORMAL env: 8/8
  PASS (fresh run). `git diff origin/main --name-only`: neither
  `merged-pr-closeout-reconciler.sh` nor
  `test-ship-flow-scheduler-backoff.sh` appears — confirms pre-existing,
  untouched by this diff.
- Live PR #91 gate check (`gh pr checks 91` at HEAD `72ccc81`):
  `invariants` PASS, `GitGuardian Security Checks` PASS, **`doc_impact`
  FAIL** — new finding, not in execute.md's gate-brief (see F2 below).

## Per-AC Evidence

- **AC-1 (batch scan-emit, all refusals before any dispatch decision) —
  VERIFIED.** refusal-batch AC-1 no-eligible cases (6/6, fresh run):
  exactly 3 distinct refusal lines for 3 refusing entities, no dispatch.
- **AC-2 (dedup window by `(slug, reason)`, reason-change re-emits) —
  VERIFIED.** refusal-batch AC-2 dedup cases (5/5, fresh run): tick 1
  emits `not-shaped`, ticks 2/3 no-op with dedup marker and emit no
  refusal line, tick 4 (DC-4 reason change) emits a fresh
  `issue-missing` refusal.
- **AC-3 (two-phase collect-then-act, first-eligible same-beat dispatch
  preserved) — VERIFIED.** refusal-batch AC-3 with-dispatch cases (6/6,
  fresh run): both refusals precede the dispatch, exactly 2 refusal
  lines. Cross-checked against fullcycle leg 3 (8/8, fresh run): a
  child that refused `not-shaped` in leg 1 still dispatches in leg 3 —
  the dedup is post-eval and case-1|2-only, not a pre-eval skip that
  would head-block the later dispatch.

## Review Findings

| # | Finding | Source | Severity | route_to | Disposition |
| --- | --- | --- | --- | --- | --- |
| F1 | gh-CLI-absence gap: `merged-pr-closeout-reconciler.sh:264`'s `command -v gh` preflight fails closed under a minimal CI-sim PATH, breaking 3 Precedence-1-exercising test files (backoff, fullcycle, reconcile) in that mode only | execute-stage panel (execute.md "Full local gate" + gate-brief) | WARNING | follow-up | Confirmed pre-existing and out of this entity's DC-1 scope (scheduler.sh fix only) — reproduced firsthand (backoff CI-sim FAIL, NORMAL env 8/8 PASS), `git diff origin/main` shows neither implicated file touched by this diff. File as a standalone todo; not this entity's fix. |
| F2 | PR #91's `doc_impact` required status check is **FAILING** at HEAD (`72ccc81`): `BLOCKER doc-impact: checker-source-map — changed plugins/ship-flow/bin/*.sh but coupled doc plugins/ship-flow/references/doc-sync-context.md not touched and no 'doc-impact: none — <reason>' declaration found` | verify-stage live-gate re-check (NEW — not surfaced in execute.md or its gate-brief) | **BLOCKING** | execute | `doc_impact` is a required branch-protection status check on `main` (confirmed via `gh api .../branches/main/protection`). This diff touches `ship-flow-scheduler.sh` and `check-invariants.sh` (both match the `checker-source-map` coupling's `bin/*.sh` glob), triggering the gate. PR body carries zero `doc-impact:` mentions (checked). The underlying doc rows for both files already exist in `doc-sync-context.md` and are accurate — `INVARIANTS.md` (the `check-invariants.sh` row's primary target) was in fact updated by this diff's own Task 4 — so there is no real doc drift, only an unmet mechanical declaration. Cheapest correct close: add a `doc-impact: none — <reason>` line (>=12-char, non-boilerplate rationale per `doc-rationale.sh`) to the PR body, e.g. citing that both changed checkers' existing Source-Map rows remain current. Not this entity's DC-1 code scope, so routed to execute/FO rather than fixed inline here. |
| F3 | Self-inflicted C15 artifact-verbosity violation on plan.md (241 body/442 raw, cap 200/400) | execute-stage deviation #1 | — | none | **RESOLVED**, confirmed by fresh re-run: `check-invariants.sh --check artifact-verbosity` → `OK C15 artifact-verbosity`, exit 0. `plan.md` is now 399 raw lines. |

## Runtime UAT

`runtime_uat`: **deferred — live tick semantics not exercisable in this
worktree.** This worktree runs `ship-flow-scheduler.sh` only in
fixture/test mode against synthetic entities under
`__tests__/fixtures/`; it is not the dedicated controller worktree
(`RUNBOOK.md`'s `<ctrl>`, a real `git worktree` on
`ship-flow-scheduler-controller` tracking `origin/main`) that the real
launchd-scheduled `tick` runs against live entity state. The batched
multi-refusal-per-beat mechanism (this entity's whole point) can only be
observed against real dormant entities with real distinct refusal
reasons, which this worktree does not have.

What proves it: once PR #91 merges to `main`, `<ctrl>` fast-forwards.
The next scheduled tick (or a manual `<bin> tick --workflow-dir <wf>
--controller-worktree <ctrl>`) should show, in
`<ctrl>/.ship-flow-scheduler-events.jsonl`, multiple distinct `refusal`
lines (one per non-eligible entity, batched before the beat's single
primary action line) instead of the pre-fix monotonous
single-entity-repeat spam that masked
`no-dangling-guard-qualifier-precision`'s real block for 2 days. FO/
post-merge heartbeat owns this check, per the same precedent as
tick-hardening's deferred live-launcher UAT.

## Verdict

**REJECTED.** Not on mechanism or test quality — every decisive suite
and all three ACs are firsthand-verified GREEN, matching execute.md's
claims exactly. REJECTED because PR #91's `doc_impact` required status
check (F2) is currently failing and the PR is genuinely not mergeable
in its present state — a live-gate result this stage is inputted to
check, and one execute.md never surfaced. This is a fast, low-risk
close (a PR-body declaration line or a `doc-sync-context.md` touch, not
a code or contract change) — re-verification after F2 closes does not
need to re-run the decisive suites, since nothing code-level changes.
F1 (pre-existing gh-CLI gap) does not block this verdict; it is
routed to follow-up. Runtime UAT is explicitly deferred with reason
above, not diluting this verdict.

## Deferred to TODO

- F1: gh-CLI-absence gap — `merged-pr-closeout-reconciler.sh:264` fails
  closed when `gh` is absent from a minimal PATH (backoff, fullcycle,
  reconcile test files exercise this path). Either fix the preflight to
  degrade more gracefully in CI-sim, or document the `gh`-on-PATH
  constraint for those suites. Not this entity's scope.

# Fix tick refusal scanning head-block — Verify (cycle 2, final)

Cycle 1 (verify.md@aabca67) REJECTED on one BLOCKING live-gate finding (F2:
PR #91's `doc_impact` required check failing) plus two codex-adversarial
code findings (F2/F3 in execute's numbering) surfaced by the FO's parallel
cross-model pass. Feedback cycle 1 landed all three fixes plus one
newly-discovered pre-existing gate gap (C11 panel-coverage-header on this
very file) found while re-running the full local gate — see `index.md`
execute cycle 2. This cycle independently re-verifies each fix firsthand
against the CURRENT branch state, not relayed from execute.md's self-report.

## Independent Re-Verification

- **`test-ship-flow-scheduler-refusal-batch.sh`: 27/27 PASS** (fresh run,
  +4 vs cycle 1's 23 — the new `run_events_log_append_failure_swallow_case`
  pinning test).
- **`test-ship-flow-scheduler-fullcycle.sh`: 8/8 PASS** (fresh run) — leg 3
  still dispatches the child; no regression.
- **`check-invariants.sh` full run (C1-C18): exit 0**, `OK C18
  refusal-observability-record` present.
- **`test-check-invariants-c18.sh`: 6/6 PASS** (fresh run) — Case B is the
  F3 fix's RED-proof pair: `FIXTURE_INVARIANTS` pointed at a missing path
  now asserts exit 1 + stderr names the missing file (was exit 0 pre-fix,
  per execute.md's `git stash` repro).
- `test-ship-flow-scheduler-rollup.sh` 10/10, `check-no-dangling.sh` PASS (8
  patterns), `check-version-triple.sh` PASS (0.9.0) — all fresh runs, no
  regressions.
- **Live PR #91 gate (`gh pr checks 91`):** first check this cycle showed
  `invariants` **FAIL** — traced to `test-merged-pr-closeout-provider-pagination.sh`
  ("GitHub provider paginates all 101 implementation commits" expected exit
  0 got 2; "GitHub provider materializes all 101 ordered source commits"),
  entirely outside this diff's touched-file set (`git diff
  origin/main...HEAD --name-only` confirms neither
  `merged-pr-closeout-reconciler.sh` nor its pagination test appears).
  `gh run rerun <id> --failed` completed **success** on retry — confirms
  CI env-flake (transient GitHub GraphQL pagination behavior in the fixture
  provider path), not a real regression; not chased further per dispatch
  instruction. `doc_impact` and `GitGuardian Security Checks` both PASS.
  Final state: **3/3 required checks green** (`gh pr checks 91` → `Passed:
  3, Failed: 0`).

## Per-AC Evidence

- **AC-1 (batch scan-emit) — VERIFIED.** refusal-batch AC-1 cases pass in
  the fresh 27/27 run; unchanged mechanism from cycle 1.
- **AC-2 (dedup window, reason-change re-emits) — VERIFIED.** refusal-batch
  AC-2 cases pass in the fresh 27/27 run; unchanged mechanism from cycle 1.
- **AC-3 (two-phase collect-then-act, first-eligible same-beat dispatch) —
  VERIFIED.** refusal-batch AC-3 cases pass; fullcycle leg 3 (8/8)
  re-confirms the child dispatches after refusing in leg 1 — the dedup
  stays post-eval, case-1|2-only, not a head-block regression.

## Review Findings

| # | Finding (cycle 1) | Severity | Cycle-2 disposition |
| --- | --- | --- | --- |
| F1 | PR #91 `doc_impact` required check FAILING — `checker-source-map` gate on `bin/*.sh` changes with no doc-impact declaration | BLOCKING | **FIXED.** PR body now carries `## Doc Impact` / `doc-impact: none — <reason>` (confirmed via `gh pr view 91 --json body`); `doc_impact` check PASS. Not a repo commit (PR body edit); retrigger commit `7b9f492` cleared a stale-payload false flag on the same check (precedented per `437bc0f`). |
| F2 | codex adversarial: events-log append-failure path — does two-phase batching introduce a NEW silent-loss mode? | code (adjudicate-or-fix) | **FIXED (adjudicated pre-existing, documented).** Commit `f5398ca`: code comment at `ship-flow-scheduler.sh:67-84` + design.md §5 revision note confirm `emit_event`'s unchecked append predates commit `193196f` (Task 1 never touched it); pinning test `run_events_log_append_failure_swallow_case` re-run PASS (part of the 27/27 above). Parity, not a new swallow — the branching instruction's "if pre-existing, document parity" path was the correct call and is independently confirmed here. |
| F3 | codex adversarial: `check-invariants.sh` C18 exits 0 when its target file is missing — fail-open false negative | code (must fail closed) | **FIXED.** Commit `3465c3e`: `check_refusal_observability_record` (`check-invariants.sh:1166-1170`) now `return 1` + stderr on a missing target file. `test-check-invariants-c18.sh` Case B re-run GREEN (6/6 total); execute.md's `git stash` repro confirms it was genuinely RED pre-fix. |
| (new) | `check-invariants.sh` C11 (panel-coverage-header) FAILED on this file at cycle-2 baseline — verify.md predated C11/C18 landing and never carried `## Panel Coverage` | compliance gap | **FIXED**, commit `77804b6` (compliance backfill, sourced from this file's own text + `index.md`'s Feedback Cycles record). This cycle-2 rewrite supersedes that backfill in place. |

## Runtime UAT

`runtime_uat`: **deferred — unchanged from cycle 1.** This worktree is not
the dedicated controller worktree (`RUNBOOK.md`'s `<ctrl>`) the real
launchd-scheduled `tick` runs against; the batched multi-refusal-per-beat
mechanism can only be observed against real dormant entities with real
distinct refusal reasons. Proof path unchanged: once PR #91 merges, `<ctrl>`
fast-forwards and the next tick's `.ship-flow-scheduler-events.jsonl` should
show multiple distinct `refusal` lines per beat instead of the pre-fix
single-entity-repeat spam. FO/post-merge heartbeat owns this check.

## Verdict

**PASS.** All three cycle-1 findings are genuinely fixed and independently
re-verified firsthand against the current branch state: F1's `doc_impact`
required check is green on the live PR, F2's append-failure behavior is
correctly adjudicated as pre-existing parity (not a new swallow) with a
pinning test that passes, and F3's C18 check now fails closed with RED
evidence re-confirmed. The one newly-discovered gap (C11 on this file) is
closed by this rewrite. Every decisive suite is green firsthand: refusal-batch
27/27, fullcycle 8/8, check-invariants C1-C18 exit 0, the new C18 test 6/6,
rollup/no-dangling/version-triple all pass. Live PR #91 gate is 3/3 green;
the one transient `invariants` failure encountered this round was traced to
an unrelated pagination fixture test (`test-merged-pr-closeout-provider-pagination.sh`,
outside this diff's touched files) and cleared on rerun — env-flake, not a
regression, not chased further. Runtime UAT stays explicitly deferred per
the reason above, not diluting this verdict. Not merged, auto-merge not
armed — that decision stays with the FO/captain.

## Panel Coverage

- Tier: B (cycle-1 FO-layer `codex exec` cross-model pass produced F2/F3,
  now fixed and independently re-verified firsthand this round — every
  fix's RED/GREEN or adjudication evidence was re-run, not taken on the
  worker's self-report). No new cross-model dispatch this cycle by design,
  mirroring the `tick-hardening` cycle-2 precedent for a scoped
  fix-verification round.
- Pass ownership: verify_agent_worker_ownership PASS; workflow_ci PASS (all
  suites + full local gate + live PR checks, firsthand); cross_model_challenge
  PASS (cycle-1 codex findings F2/F3, now fixed + re-verified); test_adequacy
  PASS (new pinning/RED tests cover exactly F2/F3's claims); runtime_uat
  deferred (see above, unchanged from cycle 1); silent_failure PASS (F2's
  swallow-parity adjudication is itself a silent-failure disposition, now
  confirmed correct); security not_triggered; type_design not_triggered;
  api_contract not_triggered; ui_design not_triggered; domain_intent
  not_triggered.

## Deferred to TODO

- F1 (cycle-1 numbering, execute-stage panel finding): gh-CLI-absence gap —
  `merged-pr-closeout-reconciler.sh:264` fails closed when `gh` is absent
  from a minimal PATH (backoff, fullcycle, reconcile test files exercise
  this path). Not this entity's scope; carried over unchanged from cycle 1.
- New candidate (from F3's fix, execute.md cycle 2): `check-invariants.sh`
  C9/C16 share the identical pre-existing fail-open `[ -f ... ] || return 0`
  skip pattern that C18 was just hardened against. Worth a follow-up to
  harden C9/C16 the same way; out of this entity's DC-1 scope (scheduler.sh
  fix only).

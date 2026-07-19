---
title: Tick hardening — delegation marker, launcher spawn, time-budget, blocked-backoff
status: verify
source: hackathon-2 contract Wave 1 (todos scheduler-tick-delegation-marker + pipeline-timeout-checkpoint-event merged; +2 Wave-0 live findings)
started: 2026-07-19T15:52:48Z
completed:
verdict:
score:
worktree: .worktrees/spacedock-ensign-tick-hardening
issue: "#74"
pr:
---

Harden the scheduler tick's spawn seam and scheduling loop. Time budget: 2h30m (hackathon-2
Wave 1). Merges two todos (same seam) plus two findings from tonight's Wave-0 launchd bring-up.

## Acceptance criteria

**AC-1 — Mechanical delegation marker.** The runner adapter passes an explicit delegation marker
(env SHIP_FLOW_SCHEDULER_TICK_ID + a prompt line naming tick id/receipt); a spawned /ship run can
distinguish tick-delegation mechanically; the decisions.md-clause workaround is retired.
Verified by: adapter fixture asserts marker presence; a delegation-aware prompt line in the spawn.

**AC-2 — Launcher spawn (probe-gated).** If `spacedock claude "<task>" -- -p`-style headless is
verified working, the adapter spawns via the spacedock launcher (wiring + version gate owned by
launcher); if the probe fails, raw `claude -p` stays with the PATH/env requirement pinned by test
and documented. Either outcome is explicit, never silent.
Verified by: recorded probe result + adapter test for the chosen path.

**AC-3 — Appetite-scaled timeout + resumable checkpoint.** Runner timeout derives from the
entity's declared time budget (generous default when absent); a timeout kill emits a checkpoint
event naming the last completed stage so resume targets the remaining stages.
Verified by: fixture with tiny budget → timeout → checkpoint event names completed stage.

**AC-4 — Blocked-backoff (no head-block).** A blocked entity does not head-block the queue: the
tick skips recently-blocked entities (machine-readable backoff state derived from events/receipts,
no new canonical store) and proceeds to the next action.
Verified by: fixture with one blocked + one eligible entity → eligible gets dispatched.

**AC-5 — Carrier PATH pinned.** The launchd plist template includes the user-local bin PATH (or
the requirement is mechanically checked at install); tonight's "claude CLI not available" class
cannot silently recur.
Verified by: plist fixture test asserts PATH; install RUNBOOK updated.

**AC-6 — Suite green both envs.** Full local gate + the three CI-sensitive tests green in normal
AND CI-simulated (no identity, no claude on PATH) environments.
Verified by: dual-env run output cited.

## Stage Report: shape

- DONE: Lean shape for a seam-hardening M entity: absorb the 6 ACs + the two Wave-0 live findings into shape.md
  `shape.md` written; launchd PATH gap cited `.ship-flow-scheduler-tick.err.log:1`; entity-7 head-block cited `.ship-flow-scheduler-events.jsonl:1`; +2 merged-todo incidents cited `.scheduler-events.jsonl:1-2`. Captain articulation (hackathon-2 GO +「原則上是都核准」2026-07-20) recorded, NOT re-asked.
- DONE: Run the AC-2 probe DURING shape; record transcript; design decision hangs on it
  Probe PASSED (exit 0, `PROBE_OK_7A9D` on stdout, ~3s); transcript in shape.md "AC-2 probe" section; decision = take the launcher path (`spacedock claude … -- -p`), fallback to raw `claude -p` documented per AC.
- DONE: Time budget 2h30m for the WHOLE entity recorded as time_budget; out-of-scope listed
  `time_budget: 2h30m` + out-of-scope (crewdock/ACP, helm adapter, upstream spacedock binary incl. nested-controller-worktree, third-party deps) in shape.md.

### Summary

Shaped as EXISTS_BROKEN seam-hardening (reverse-recovery layer-trace: all five seams exist, none MISSING → no greenfield, no new canonical store). AC-2 probe run live during shape resolved the one open design decision — the spacedock launcher supports headless `-p` passthrough with a parseable exit, so AC-2 takes the launcher path and design is trivial-pass. Each mechanism AC is paired to the specific Wave-0 incident it prevents; typed DCs, ROADMAP now-row intent (fold two Later todos), and canonical-doc impact (RUNBOOK + scheduler design authority; no new ARCHITECTURE section) are handed off to design.

## Stage Report: design

- DONE: design.md fixes the concrete deltas for all 6 ACs against the REAL origin/main files (adapter, tick, tick plist, l3 events schema)
  `design.md` written; every delta cites file:line — AC-1 delegation marker (`scheduler-runner-adapter.sh:64` prompt + `:40,54-58` `--env`; tick `--tick-id` from `:322`), AC-2 launcher spawn, AC-3 timeout+checkpoint, AC-4 backoff (`ship-flow-scheduler.sh:355-357` root), AC-5 plist PATH (`…tick.plist:31`).
- DONE: delegation marker env+prompt shape
  Optional `--tick-id` → `SHIP_FLOW_SCHEDULER_TICK_ID` on child (both branches, testable) + a `/ship <entity>` delegation prompt line naming tick_id/receipt; consumer = spawned FO stamps its stage-entry receipt, retiring the 30-min heuristic.
- DONE: launcher spawn command line + raw fallback
  Decided `--plugin-dir` over `--skip-compat-check` — `spacedock claude --help` (v0.25.0, verified) says `--plugin-dir` relaxes the version gate AND loads the worktree's own plugin checkout; resolves shape residual (a) without deferral. Command: `${SPACEDOCK_BIN:-spacedock} claude "$SHIP_PROMPT" --plugin-dir "$WORKDIR/plugins/ship-flow" -- -p --output-format text`. Raw `claude -p` documented as fallback (never silent).
- DONE: timeout derivation from time_budget (default when absent)
  `derive_timeout_sec` reads optional frontmatter `time_budget` (`<N>h<M>m`→sec), generous default 5400s; DC-4 checkpoint = extend `blocked` detail with `checkpoint.resume_stage` (keeps one-event-per-tick + rollup forward-compat), NOT a new event value.
- DONE: blocked-backoff derivation (from events/receipts — NO new canonical store, Rule 3)
  `entity_in_backoff` reads `events.jsonl` only (reuses `scheduler_lease_epoch`); precedence-1 `continue` instead of `return 0` fixes the head-block; DC-3 skip-past ≠ retry held; window default 3600s.
- DONE: plist PATH fix
  `@USER_LOCAL_BIN@` placeholder prepended to tick plist PATH + install-time substitution (DC-5: no hardcoded `/Users/kent`; launchd cannot expand `$HOME`).
- DONE: Name the test surfaces per AC (existing test-*.sh extended vs new fixtures)
  AC-1/2/3 → extend `test-scheduler-runner-adapter.sh` (+ hermetic `--print-spawn` mode); AC-4 → NEW `test-ship-flow-scheduler-backoff.sh`; AC-5 → extend `test-ship-flow-scheduler-plist.sh`; AC-6 → three CI-sensitive tests named (adapter, backoff/tick-spawn, reconcile/fullcycle git-identity).
- DONE: respect the ten hardening hard rules from the l3 shape
  Rule 3 (no new store — backoff/checkpoint event-derived), Rule 4 (no retry — skip-past), Rule 10 (dumb invoker — DC-1 held, tick passes opaque id only) all preserved; DC resolution table in design.md.

### Summary

Contract-bearing design (not trivial-pass): schema field (`checkpoint.resume_stage`), adapter CLI surface (`--tick-id`, `--print-spawn`), and plist template all change. The one shape-residual open decision (AC-2 version-gate mode) is resolved in design against verified `spacedock claude --help` evidence — `--plugin-dir` beats `--skip-compat-check` because it loads the controller-worktree's own plugin checkout. DC-4 (checkpoint) decided in-place (extend `blocked` detail) to hold the one-event-per-tick + rollup-forward-compat contracts. Four items parked as tunables/execute-probes; zero new captain decisions.

## Stage Report: plan

- DONE: plan.md decomposes design.md into serial atomic-commit TDD tasks (RED fixture first per AC, fix, green cited) with exact-command DCs; runtime commands from the repo's existing shell-test harness; every deliverable inside plugins/ship-flow/{bin,lib,references} + the launchd template — no SKILL edits
  `plan.md` written; 9 atomic tasks (AC-1a/1b/1c, AC-2, AC-3a/3b, AC-4, AC-5, canonical-docs) each with named RED test case, GREEN implementation sketch grounded in real `origin/main` line numbers, and an exact `bash plugins/ship-flow/lib/__tests__/test-*.sh` DC.
- DONE: Budget realism — entity time_budget 2h30m, ~50m spent through design — size the plan to ~1h execute + ~40m verify/ship; anything over goes to the cut-list as a named follow-up, never silently included
  9 tasks × ~6-7m ≈ 60m execute; 2 items explicitly named to the cut-list (AC-4 precedence-2 dispatch-repeat test coverage; ROADMAP Later-row fold, cross-branch/FO-owned) rather than silently included or excluded.
- DONE: Terminal DCs — dual-env green (normal + CI-sim no-identity no-claude-on-PATH) for the three CI-sensitive tests + new backoff test; the LIVE proof is FO-owned post-merge, planned as a documented handoff not an execute task
  `plan.md` "Terminal DCs" section gives the exact dual-env command pair (`bash` normal + `env -i PATH=/usr/bin:/bin ... CI=true bash`, matching `.github/workflows/ship-flow-invariants.yml:110-118`'s shape) plus a full-suite regression sweep; "Post-merge FO handoff" section names the live-proof target (`no-dangling-guard-qualifier-precision`) without turning it into an execute task.

### Summary

Plan grounded directly against the live `origin/main` code (not just design.md's prose): read the
actual `scheduler-runner-adapter.sh` (93 lines), `ship-flow-scheduler.sh` (760 lines), the tick
plist, and every existing test file + fixture the plan's new tests reuse or extend. Found and
resolved one real regression risk design.md's prose would have introduced — AC-3's
`derive_timeout_sec` override, read literally, breaks the existing
`run_tick_surfaces_timeout_as_blocked_case` test (its `--timeout 1` would get silently overridden
to a 5400s default, turning a forced-timeout assertion into a false pass/fail); resolved by making
the entity's `time_budget` an override ONLY when present, with the CLI-supplied timeout_sec as the
unconditional fallback default. Also resolved: the ROADMAP.md "fold two Later rows" instruction
from shape.md turned out to reference rows that exist only on the separate `iamcxa/muscat-v1`
branch (not in this worktree's history) — documented as a cross-branch cut-list item rather than
fabricated-then-removed. All 6 ACs are covered by named, atomic, RED-before-GREEN tasks with exact
verification commands; AC-6 and the live proof are correctly kept out of execute/verify scope per
the dispatch checklist.

## Stage Report: execute

- DONE: Execute the 9-task plan in order with RED-before-GREEN evidence per task cited in execute.md; the timeout-override semantics are plan's (time_budget overrides ONLY when present; CLI timeout_sec is the unconditional fallback) — design prose loses where they conflict
  9 tasks committed serially `eb910b6`..`64ae2f6`, each with an observed RED run (exit-2/failed-assertion) before its GREEN; per-task citations in `execute.md`. Plan's timeout semantics implemented exactly: `derive_timeout_sec` returns the CLI default UNCHANGED when `time_budget` absent (existing `--timeout 1` test preserved); `cmd_tick` compiled default 900→5400. AC-2 execute-time probe run for real: `spacedock claude … --plugin-dir <worktree>/plugins/ship-flow -- -p --output-format text` → exit 0, `PROBE_OK`.
- DONE: Full local gate before handoff: all scheduler tests (incl. the NEW backoff test) + shell suite + node + the three check-* scripts, in BOTH normal and CI-sim (no identity, no claude on PATH) envs; git diff --check clean; shellcheck clean
  Normal env: 9/9 scheduler files exit 0. CI-sim (`env -i`, empty HOME, no claude/spacedock on PATH): adapter 33/33, backoff 8/8, reconcile 16/16, fullcycle 8/8, all exit 0. Full sweep 130 files green (one file needs >90s locally; exit 0 at 300s, 198/198 — untouched by this diff). node 79/79. check-invariants exit 0 (after fixing a real C15 blocker on plan.md, commit `9a28831`), check-no-dangling PASS, check-version-triple PASS. shellcheck clean on all 6 changed .sh files. git diff --check clean after this append.
- DONE: Boundary: the LIVE proof (hardened tick dispatches the held W2a entity) is FO-owned post-merge — do NOT run it from this worktree; the muscat-v1 ROADMAP fold is FO cut-list, skip it; budget ~1h for execute — anything beyond the 9 tasks parks to the report
  LIVE proof not run (FO-owned post-merge, target named in plan.md's handoff section); ROADMAP Later-row fold skipped (cross-branch, cut-list); one unplanned-but-necessary fix (plan.md C15 verbosity gate) recorded as deviation #1 in execute.md rather than silently absorbed.

### Summary

All 9 plan tasks landed as atomic TDD commits on `spacedock-ensign/tick-hardening` (`eb910b6`..`9a28831` + `9312242` for execute.md): delegation marker (--tick-id → env + prompt line, threaded from the tick), launcher spawn via `${SPACEDOCK_BIN:-spacedock} claude --plugin-dir … -- -p` with widened preflight, time_budget-derived timeout + run-timeout checkpoint detail, events-derived blocked-backoff fixing the Wave-0 head-block, and the @USER_LOCAL_BIN@ plist PATH pin. Two notable calls: the AC-2 --plugin-dir level was probe-verified against the real launcher (not just hermetically), and a pre-existing-on-this-branch C15 verbosity failure on plan.md was fixed in-stage because the gate is part of this stage's handoff contract. Dual-env gate fully green; live proof and cross-branch doc folds handed to the FO per plan.

## Stage Report: verify

- DONE: Independent re-run (FOREGROUND bounded calls only, ≤600s each, sequential): the 9 scheduler tests + new backoff test in normal AND CI-sim env, then full suite + the three check-* scripts; per-AC (AC-1..AC-6) evidence citations with the DC table; spot-check the two deviations
  139/139 scheduler assertions (NORMAL); 4 CI-sensitive files re-verified in a faithfully-rebuilt CI-sim (plan.md's literal PATH recipe isn't reproducible on this macOS box — `timeout` isn't in `/usr/bin:/bin` here — rebuilt an isolated-timeout-only PATH sim instead, matching execute.md's counts exactly); full suite 130/130 (129 within 90s cap, 1 confirmed 198/198 at 300s); node 79/79; check-invariants/no-dangling/version-triple all exit 0; both deviations spot-checked and confirmed legitimate — see `verify.md`.
- DONE: Cross-model challenge REQUIRED before gate queue (source-bearing M diff): host-opposite per ship-verify on the execute diff; DEGRADED visibly if unavailable — never silent, and note it blocks nothing alone but must be declared
  `codex exec` (codex-cli 0.144.1, gpt-5.6-sol) ran live against `97cb9b5..HEAD`, NOT degraded; findings converged with an independently-dispatched `pr-review-toolkit:code-reviewer` pass. Three findings verifier-reproduced firsthand (not taken on citation): a confirmed command-injection PoC in `SPAWN_LINE`/`bash -c`, and two `derive_timeout_sec` boundary bugs (`0m` disables the timeout per GNU semantics; leading-zero `time_budget` crashes on bash octal arithmetic) — see `verify.md` Review Findings.
- DONE: verify.md C11/C12/C15-conformant from the start (## Panel Coverage, ## Deferred to TODO, ≤120 body lines). runtime_uat: fixture-level + the real launcher probe receipt; the LIVE proof declared "deferred — FO-owned post-merge". BLOCKING → route_to execute; NITs per auto-fix rules
  `verify.md` written (119 body lines per the C15 formula, both mandatory H2 headers present); `check-invariants.sh` confirms `OK C11`/`OK C12`/`OK C15`. `runtime_uat` = 139/139 fixture assertions + 2 live `spacedock claude --plugin-dir` probes (both exit 0, mechanism proven; content declined by the spawned FO on unrelated grounds). LIVE proof explicitly deferred per plan.md's handoff. Verdict: **NOT PASS (VETO) — route_to: execute** (3 BLOCKING, all verifier-reproduced); Bounce Tasks named for `derive_timeout_sec` input validation and the `SPAWN_LINE` injection fix.

### Summary

Independent re-verification found real regressions execute.md's dual-env-green self-report did not surface: a confirmed shell-command-injection PoC in the new `SPAWN_LINE`/`bash -c` spawn path (Task 4), and two untested `derive_timeout_sec` boundary bugs (Task 5) — a `0m` time_budget silently disables the timeout entirely (GNU `timeout 0` = no enforcement), and a leading-zero value (`08m`) crashes the function via bash's octal-literal arithmetic. All three were independently reproduced by a live `codex exec` cross-model challenge AND a from-scratch `pr-review-toolkit:code-reviewer` dispatch before being confirmed firsthand by direct exercising (not taken on citation). Verdict is NOT PASS, routing back to execute with two required, mechanical AUTO-FIX-class fixes plus one recommended companion fix (preflight/spawn mismatch). All quality-gate re-runs (139 scheduler assertions, 130-file full suite, node, three check-* scripts) matched execute.md's claims exactly once the CI-sim methodology was corrected for this machine's missing GNU `timeout` binary.

### Feedback Cycles

- cycle: 1
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-19T18:39:16Z
  verify_artifact: verify.md@856b4cf

## Stage Report: execute (cycle 2)

- DONE: Execute the 9-task plan in order with RED-before-GREEN evidence per task cited in execute.md; the timeout-override semantics are plan's (time_budget overrides ONLY when present; CLI timeout_sec is the unconditional fallback) — design prose loses where they conflict.
  Cycle 2 is a feedback-fix redo, not a fresh 9-task run: cycle 1's 9 tasks stand unchanged. Fixed exactly the 3 verify-cycle-1 bounce findings as 3 atomic RED-before-GREEN commits — B2/B3 `derive_timeout_sec` (`9f8957c`), B1 `SPAWN_ARGV` exec (`3a29309`), W1 companion preflight (`6ee6867`) — each RED-reproduced against the pre-fix code before applying GREEN, cited in execute.md's "Feedback Cycle 1 fixes" addendum. The time_budget-overrides-only-when-present semantic is untouched by the B2/B3 fix (only base-10 parsing + zero-total fallback added).
- DONE: Full local gate before handoff: all scheduler tests (incl. the NEW backoff test) + shell suite + node + the three check-* scripts, in BOTH normal and CI-sim (no identity, no claude on PATH) envs; git diff --check clean; shellcheck clean.
  Re-ran FOREGROUND both envs: adapter suite 46/46 (was 33; +13 new bounce-fix assertions), normal AND CI-sim (isolated `timeout`-only PATH, no claude/spacedock, empty HOME, CI=true) — identical counts, no PATH-dependence in the new assertions. Full 9-file scheduler set all exit 0 both envs. Full 130-file shell sweep: 129/130 within the 90s CI cap; the one pre-existing >90s file (`test-merged-pr-closeout-reconciler.sh`, confirmed untouched via `git diff --stat`) green at 300s (198/198) — same finding execute.md cycle 1 and verify.md cycle 1 both hit. node 79/79. `check-invariants`/`check-no-dangling`/`check-version-triple` all exit 0. `shellcheck` 0.11.0 clean on both changed production files + the test file + the new stub fixture. `git diff --check` clean.
- SKIPPED: Boundary: the LIVE proof (hardened tick dispatches the held W2a entity) is FO-owned post-merge — do NOT run it from this worktree; the muscat-v1 ROADMAP fold is FO cut-list, skip it; budget ~1h for execute — anything beyond the 9 tasks parks to the report.
  LIVE proof not run (FO-owned post-merge, unchanged). ROADMAP fold not touched (cross-branch, FO cut-list). `verify.md` not touched per the dispatch's explicit instruction. This narrowly-scoped bounce-fix cycle used well under the 1h budget.

### Summary

Verify cycle 1 VETO'd on three findings (all AUTO-FIX-class): a confirmed command-injection PoC in the adapter's `SPAWN_LINE`/`bash -c` spawn path (B1), and two `derive_timeout_sec` boundary bugs — a leading-zero `time_budget` crashing bash's octal-literal arithmetic (B2) and a zero-total silently disabling the timeout via GNU `timeout 0` (B3) — plus a recommended companion (W1: preflight accepted `claude` though no such fallback is wired). Each fixed as an isolated, atomic commit with RED reproduced live against the pre-fix code (not asserted from memory) before applying the GREEN fix: B1 now execs a single `SPAWN_ARGV` directly, never re-parsed by a shell; B2/B3 force base-10 arithmetic and reject a zero total back to the caller's default; W1's preflight now requires `spacedock`/`$SPACEDOCK_BIN` specifically. 13 new assertions added to `test-scheduler-runner-adapter.sh` (46/46 total, dual-env-identical). Full local gate re-run FOREGROUND in both normal and CI-sim environments matches cycle 1's clean baseline exactly, with the one pre-existing >90s file reconfirmed untouched and green. `verify.md` left untouched per the dispatch's explicit instruction; the LIVE proof and ROADMAP fold remain FO-owned, unchanged from cycle 1's handoff.

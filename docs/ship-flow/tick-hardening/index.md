---
title: Tick hardening — delegation marker, launcher spawn, time-budget, blocked-backoff
status: plan
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


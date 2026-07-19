---
title: Tick hardening — delegation marker, launcher spawn, time-budget, blocked-backoff
status: shape
source: hackathon-2 contract Wave 1 (todos scheduler-tick-delegation-marker + pipeline-timeout-checkpoint-event merged; +2 Wave-0 live findings)
started: 2026-07-19T15:52:48Z
completed:
verdict:
score:
worktree:
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

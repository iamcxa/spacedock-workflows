# ship-flow-scheduler recovery runbook

Operational reference for the L3 scheduler tick (design.md §8, AC-6). The daemon
owns NO canonical state — every projection re-derives from entity frontmatter +
gh reads, so recovery is always "inspect, unlock if provably stale, rerun once by
hand". It never mutates prompts, routing, budgets, or policy.

Substitute throughout:

- `<ctrl>` — the dedicated controller worktree (a real git worktree on a
  dedicated branch, never a shared Conductor tree; created during T0 as
  `git worktree add <ctrl> -b ship-flow-scheduler-controller origin/main`).
  This session's instance: `.worktrees/ship-flow-scheduler-controller` under
  the repo root.
- `<wf>` — the workflow dir, e.g. `<repo>/docs/ship-flow`.
- `<bin>` — `plugins/ship-flow/bin/ship-flow-scheduler.sh` (repo-relative).

## Inspect

- **Morning queue (read-only, safe anytime):**
  `<bin> report --workflow-dir <wf>` — one row per non-terminal projection
  (`awaiting_merge` / `merged`). `--json` for machine reads. Running it twice
  is harmless; it derives, never writes.
- **Event log:** `tail -20 <ctrl>/.ship-flow-scheduler-events.jsonl` — one JSON
  line per tick action (`dispatch|advance|reconcile|no-op|refusal|blocked`).
  The log is an audit cache, never a decision input; deleting it loses history
  but breaks nothing.
- **Lease record:** `cat <ctrl>/.ship-flow-scheduler.lease/record` — shows
  `pid=`, `start_ts=`, `tick_id=`, `entity=`. A held lease with a live pid
  means a run is in flight; every interval tick meanwhile no-ops
  (`reason=lease-held`), which is normal.
- **Run receipts:** `ls <ctrl>/.ship-flow-scheduler-receipts/` — one file per
  adapter spawn (the `receipt` path cited in dispatch/blocked events). A
  dispatch's receipt now also carries `SHIP_FLOW_SCHEDULER_TICK_ID` / a
  delegation prompt line (tick-hardening AC-1) — the spawned `/ship` run's
  mechanical proof of tick-delegation, retiring the prior 30-min-receipt
  heuristic clause in an entity's `decisions.md`.

## Unlock

Remove the lease dir ONLY when it is provably stale — BOTH checks, in order:

1. `kill -0 "$(awk -F= '$1=="pid"{print $2}' <ctrl>/.ship-flow-scheduler.lease/record)"`
   fails (holder process is dead), AND
2. `start_ts` in the record is older than the run timeout (default 900s).

Then: `rm -rf <ctrl>/.ship-flow-scheduler.lease`

Never remove a live holder's lease — that re-opens the double-dispatch window
the lease exists to close. Note the tick self-heals stale leases on its next
invocation, but ONLY on a provably-dead holder (feedback cycle 1, F2: age
alone is never sufficient — a still-alive holder is never auto-reclaimed, no
matter how old its record). A slow reconcile is itself now bounded by
`--timeout`, so a holder that overruns is forcibly ended rather than merely
outliving the timeout window — it becomes reclaimable via the dead-pid path
above, not a separate age heuristic. Manual unlock is only needed when you
want an immediate rerun and can independently prove the two conditions above.

## Rerun

One bounded action by hand (identical to what launchd fires):

    <bin> tick --workflow-dir <wf> --controller-worktree <ctrl> \
      --runner gh --events-log <ctrl>/.ship-flow-scheduler-events.jsonl

Exit 0 = healthy tick (including refusal/blocked/no-op outcomes — read the
emitted event). Exit 2 usage, 3 environment fault (missing dir/tool), 4 lease
subsystem fault. Re-running after a crash is always safe: dispatch eligibility
excludes any entity with a live worktree or PR, so a replay cannot double-ship.

**Resume from checkpoint (tick-hardening AC-3):** a timeout-blocked entity's
`blocked` event carries `detail.checkpoint.resume_stage` — the entity's
frontmatter `status` at kill time. `tail` its latest `run-timeout` event in
the events log to see which stage to re-enter by hand (or let the next real
tick's own eligibility re-derivation pick it back up); this is a read of an
existing event, not a new store (Rule 3).

## launchd install / uninstall (manual, v0)

Templates: `plugins/ship-flow/references/launchd/com.spacedock.ship-flow-scheduler.{tick,rollup}.plist`

1. Substitute placeholders and install:

       sed -e "s|@CONTROLLER_WORKTREE@|<ctrl>|g" \
           -e "s|@SPACEDOCK_BIN@|$(command -v spacedock)|g" \
           -e "s|@WORKFLOW_DIR@|<wf>|g" \
           -e "s|@USER_LOCAL_BIN@|$HOME/.local/bin|g" \
           plugins/ship-flow/references/launchd/com.spacedock.ship-flow-scheduler.tick.plist \
           > ~/Library/LaunchAgents/com.spacedock.ship-flow-scheduler.tick.plist
       launchctl load ~/Library/LaunchAgents/com.spacedock.ship-flow-scheduler.tick.plist

   (Same for the rollup plist — it has no `@USER_LOCAL_BIN@` token since it
   never spawns `claude`/`spacedock`; that `-e` line is simply a no-op for it.)

   `@USER_LOCAL_BIN@` MUST resolve to wherever `claude`/`spacedock` actually
   live for this machine's login shell (typically `$HOME/.local/bin` — never
   a hardcoded `/Users/kent`; launchd does not expand `$HOME` itself in
   `EnvironmentVariables`, so the substitution above must happen at install
   time). This closes the "claude CLI not available" class that recurs when
   the tick plist's PATH omits the directory the real binaries are on.

2. Uninstall / pause:

       launchctl unload ~/Library/LaunchAgents/com.spacedock.ship-flow-scheduler.tick.plist

3. Daemon health: launchd surfaces nonzero tick exits; the logs are
   `<ctrl>/.ship-flow-scheduler-tick.log` / `.err.log`. A blocked ENTITY is
   exit 0 by design — only environment/lease faults are nonzero.

## Daily rollup

`<bin> rollup --events-log <ctrl>/.ship-flow-scheduler-events.jsonl --date YYYY-MM-DD`
— deterministic counts only (dispatches, durations, gate waits, failures,
costs, interventions); byte-identical for the same input; no wall-clock in the
body. The 23:55 launchd job appends to `<ctrl>/.ship-flow-scheduler-rollups.md`.

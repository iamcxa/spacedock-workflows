---
tid: scheduler-tick-delegation-marker
captured_at: 2026-07-19T11:18:14Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/lib/scheduler-runner-adapter.sh, plugins/ship-flow/bin/ship-flow-scheduler.sh]
suggest_done_type: code
entity: null
---

scheduler-runner-adapter delegation token — the tick's spawned `claude -p "/ship <entity>"` run cannot mechanically distinguish tick-delegation from forbidden hand-dispatch; tonight's live proof blocked on this ambiguity (2026-07-19T11:15Z receipt). v0 workaround = decisions.md delegation clause (receipt younger than 30 min). Proper fix: adapter passes an explicit delegation marker (env var SHIP_FLOW_SCHEDULER_TICK_ID + a prompt line naming the tick id/receipt) and the ensign/FO contract recognizes it; plus rollup should count delegation-ambiguity blocks. Source: l3-scheduler-tick live proof, blocked receipt 20260719T110743Z.

Captain direction (2026-07-20): fold the runner-spawn upgrade into this same wedge — replace the
raw `claude -p` spawn in scheduler-runner-adapter.sh with the spacedock front-door launcher
(`spacedock claude` / `spacedock codex`) IF a headless mode is verified (probe first, do not
assume). Rationale: launcher owns plugin/env wiring + binary-version gate; it is also the correct
place to stamp the delegation/session metadata this todo exists for; `--host codex` opens
cross-vendor runners; future ACP transport arrives via the launcher without touching tick
internals. Same seam, one wedge.

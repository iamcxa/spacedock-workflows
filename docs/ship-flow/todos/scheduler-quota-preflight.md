---
tid: scheduler-quota-preflight
captured_at: 2026-07-21T00:13:28Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/lib/scheduler-runner-adapter.sh, plugins/ship-flow/bin/ship-flow-scheduler.sh]
suggest_done_type: code
entity: null
---

Scheduler quota preflight: the tick spawns claude runs blind. Evidence (receipt 20260720T163634Z-4318): at session-limit exhaustion it still spawned, burned a slot, got "You've hit your session limit · resets 3:50am", recorded run-error, entered the 1h blocked-backoff. The runner adapter should preflight quota (cheap probe, or parse the limit message fast-fail) and emit a distinct quota-exhausted event with a reset-time-aware backoff instead of spawning. Pairs with fo-clock-quota-awareness (the FO-side discipline); this is the scheduler-side gate.

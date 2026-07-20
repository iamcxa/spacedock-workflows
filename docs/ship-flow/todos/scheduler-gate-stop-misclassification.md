---
tid: scheduler-gate-stop-misclassification
captured_at: 2026-07-20T16:34:07Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/bin/ship-flow-scheduler.sh, plugins/ship-flow/lib/scheduler-runner-adapter.sh]
suggest_done_type: code
entity: null
---

Scheduler tick misclassifies a gate-stop bounded run as run-error: when the tick-spawned /ship run correctly stops at a captain gate (no conn grant — presents and exits), the scheduler records event=blocked reason=run-error and puts the entity into the 3600s blocked-backoff window — a misleading audit event AND a one-hour delay on legitimate post-approval redispatch. The runner adapter should distinguish gate-stop exits (a successful bounded outcome — e.g. a gate-stop marker in run output or a distinct exit code) from real run errors, emit a truthful event kind/reason, and skip backoff for gate-stops. Evidence: receipt 20260720T152942Z-12916 (perfect #75 shape-gate presentation classified as run-error, 2026-07-20).

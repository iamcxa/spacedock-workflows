---
tid: pipeline-timeout-checkpoint-event
captured_at: 2026-07-19T12:49:58Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/lib/scheduler-runner-adapter.sh, plugins/ship-flow/bin/ship-flow-scheduler.sh]
suggest_done_type: code
entity: null
---

scheduler tick runner timeout budget — the adapter's --timeout is a flat knob (5400s tonight) but a full autonomous pipeline run (design→plan→execute→verify→ship) exceeds it; the live proof was killed between execute and verify. Timeout should scale with entity size/appetite or default much larger, and a timeout kill should emit a resumable checkpoint event naming the completed stage. Source: l3-scheduler-tick live proof, blocked reason=run-timeout 2026-07-19T12:47Z.

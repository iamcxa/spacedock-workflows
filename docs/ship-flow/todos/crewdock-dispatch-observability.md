---
tid: crewdock-dispatch-observability
captured_at: 2026-07-21T00:13:28Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/bin/ship-flow-scheduler.sh, docs/ship-flow/_mods/]
suggest_done_type: code
entity: null
---

Crewdock dispatch observability binding (captain direction 2026-07-21): tick events.jsonl + receipts are machine-local — no fleet view, no token accounting; the captain cannot observe background token burn. Gradually bind autonomous dispatch to crewdock: export dispatch/blocked/refusal/completion events plus per-run token usage (capture claude -p usage into receipts first) so burn is observable per entity/beat/machine. Staged: (1) usage into receipts, (2) events exporter, (3) crewdock surface.

---
tid: tick-refusal-scan-head-block
captured_at: 2026-07-19T20:25:27Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/bin/ship-flow-scheduler.sh]
suggest_done_type: code
entity: null
---

A refusal consumes the tick's single bounded action and refusals are not deduped/backoff-cached, so the eligibility scan re-refuses the alphabetically-first dormant entity every beat and never reaches later eligible entities (20:15+20:20 identical refusal beats on 2-deterministic-manual-adopter-routing while shaped+approved no-dangling-guard-qualifier-precision sat waiting). Fix: refusals are scan-events not the beat's action (batch-emit, then dispatch the first eligible in the same beat) + refusal dedup window. This blocked hackathon-2's live finale.

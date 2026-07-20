---
tid: scheduler-dor-gate-accepts-inline-shape
captured_at: 2026-07-20T02:35:00Z
status: pending
domain: infra
guess_files: [plugins/ship-flow/bin/ship-flow-scheduler.sh]
suggest_done_type: code
entity: null
---

**Concurrent finding from R2 shape** (tick-refusal-scan-head-block): the finale's `no-dangling-guard-qualifier-precision` (#75) block was NOT caused by the batching/dedup bug — it was `dor-stale-shape`. The `dor_pass()` function at `ship-flow-scheduler.sh:264-267` requires a non-empty `shape.md` sidecar file, but #75 keeps its shape content in `index.md`'s body (per the workflow's `status: shape` + inline-body convention). Broadening `dor_pass()` to accept either a `shape.md` sidecar OR `status: shape|design|...` with non-empty body would fix the concurrent gate. R2's recommendation: keep R2 narrow (batching+dedup only), file this separately.

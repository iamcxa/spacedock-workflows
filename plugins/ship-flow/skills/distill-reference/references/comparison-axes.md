# Distill Reference Comparison Axes

Use these axes for every `/ship-flow:distill-reference` report. Keep the field names stable so future reports can be compared mechanically.

| Axis | Field | Question | Fit notes |
|---|---|---|---|
| Granularity | `granularity` | Does the source operate per pitch, per iteration, per target system, or at another unit of work? | Prefer patterns that preserve ship-flow's entity/stage model. |
| Autonomy stance | `autonomy_stance` | When does the source ask a human, proceed autonomously, or escalate only on catastrophe? | Preserve density-aware autonomy and explicit gate semantics. |
| Subagent dispatch | `subagent_dispatch` | Does the source use named teammates, fresh-context agents, generic role agents, or inline work? | Prefer patterns compatible with ship-flow named teammate + fallback model. |
| Evidence model | `evidence_model` | What evidence proves the source's decisions: done criteria, behavior corpus, provenance, tests, screenshots, or review matrices? | Prefer evidence that can become plan/verify checks. |
| Gate philosophy | `gate_philosophy` | Does the source use a single reviewer, PAR/multi-agent review, captain confirmation, or no explicit gate? | Prefer gates that are boolean, auditable, and cheap to verify. |
| State persistence | `state_persistence` | Where does the source keep state: entity files, workspace files, logs, memory stores, or ad hoc session state? | Prefer committed, reviewable ship-flow artifacts. |
| Hermetic fit | `hermetic_fit` | Can the method be copied as ship-flow-owned prose/tests without runtime dependency on the source system? | Reject imports that require source-local daemons, paths, binaries, or state. |

## Scoring

Use these scores for each axis:

- `high`: clear value, low implementation cost, compatible with ship-flow invariants.
- `medium`: useful but needs shaping, narrowing, or follow-up validation.
- `low`: minor value or high cost relative to expected benefit.
- `not-fit`: conflicts with ship-flow principles, stage boundaries, or hermeticity.
- `no-evidence`: source unavailable or evidence insufficient.

Every high/medium score that becomes a candidate must cite source evidence and ship-flow baseline evidence.

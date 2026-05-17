# Distillation Report Template

Path template: `docs/ship-flow/_distillations/<yyyy-mm-dd>--<report-name>.md`

`<report-name>` is the validated output slug. By default, it is derived from the source identity; `--report-name <slug>` overrides the derived filename slug.

This is the reusable report format. Do not put first-run-specific content in this template.

## Source Identity

```yaml
source_name:
source_kind: local-path|git-working-tree|url|mixed
source_ref:
target: ship-flow
report_instance:
reusable_skill: plugins/ship-flow/skills/distill-reference/SKILL.md
generated_at:
```

## Source Availability

| Source | Status | Evidence | Notes |
|---|---|---|---|
| `<path-or-url>` | `read`, `missing`, `inaccessible`, `remote-unavailable`, or `skipped-out-of-scope` | `<path:line or command evidence>` | `<notes>` |

Missing sources are evidence about availability only. Do not infer source behavior from absent content.

## Source Read List

| Source | Why read | Evidence |
|---|---|---|
| `<path>` | `<reason>` | `<path:line>` |

## Target Map

| Ship-flow surface | Why relevant | Evidence |
|---|---|---|
| `<path>` | `<axis or candidate>` | `<path:line>` |

## Comparison Axes

| Axis | Source has | Ship-flow has | Gap score | Evidence |
|---|---|---|---|---|
| `granularity` |  |  | `high`, `medium`, `low`, `not-fit`, or `no-evidence` |  |
| `autonomy_stance` |  |  | `high`, `medium`, `low`, `not-fit`, or `no-evidence` |  |
| `subagent_dispatch` |  |  | `high`, `medium`, `low`, `not-fit`, or `no-evidence` |  |
| `evidence_model` |  |  | `high`, `medium`, `low`, `not-fit`, or `no-evidence` |  |
| `gate_philosophy` |  |  | `high`, `medium`, `low`, `not-fit`, or `no-evidence` |  |
| `state_persistence` |  |  | `high`, `medium`, `low`, `not-fit`, or `no-evidence` |  |
| `hermetic_fit` |  |  | `high`, `medium`, `low`, `not-fit`, or `no-evidence` |  |

## Gap Scoring

Summarize why each high/medium gap should or should not become a candidate.

## Candidates

### Candidate: `<slug>`

```yaml
id:
title:
source_axis:
target_area:
fit_score:
source_evidence:
  - path:line or source_unavailable record
ship_flow_baseline:
  - path:line
proposed_change:
hermeticity_note:
verification_idea:
proposed_followup:
  kind: todo or entity
  slug:
  body: |
    <markdown>
# Or, only when status is already-owned:
proposed_followup: null
status: proposed, filed, rejected, or already-owned
```

## Rejected Imports

| Pattern | Reason rejected | Evidence |
|---|---|---|
|  |  |  |

## Follow-up Status

| Candidate | Status | Follow-up |
|---|---|---|
|  | `proposed`, `filed`, `rejected`, or `already-owned` |  |

## Hermeticity Audit

| Check | Result | Evidence |
|---|---|---|
| No load-bearing source runtime paths | `PASS` or `FAIL` |  |
| Missing sources recorded explicitly | `PASS` or `FAIL` |  |
| Candidates cite source and baseline evidence | `PASS` or `FAIL` |  |

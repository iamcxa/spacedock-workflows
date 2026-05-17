# Candidate Capture Rules

Candidate capture turns high/medium comparison gaps into captain-reviewable follow-up drafts. A candidate is not an implementation change and does not directly edit ship-flow stage skills, `lib/`, PRODUCT, ARCHITECTURE, or INVARIANTS.

## Candidate Schema

```yaml
id: string
title: string
source_axis: granularity | autonomy_stance | subagent_dispatch | evidence_model | gate_philosophy | state_persistence | hermetic_fit
target_area: ship | ship-shape | ship-plan | ship-design | ship-execute | ship-verify | ship-review | lib | docs | invariants
fit_score: high | medium | low | not-fit | no-evidence
source_evidence:
  - path:line or source_unavailable record
ship_flow_baseline:
  - path:line
proposed_change: string
hermeticity_note: string
verification_idea: string
proposed_followup:
  kind: todo or entity
  slug: string
  body: markdown
# Or, only when status is already-owned:
proposed_followup: null
status: proposed | filed | rejected | already-owned
```

## Field Rules

- `id`: stable kebab-case identifier unique within the report.
- `title`: concise human-readable candidate title.
- `source_axis`: exactly one comparison axis that primarily motivated the candidate.
- `target_area`: the likely ship-flow surface for a future entity, including top-level `ship` orchestration when the candidate spans stage boundaries.
- `fit_score`: `high` or `medium` for candidates worth follow-up; use `low`, `not-fit`, or `no-evidence` only in rejected imports or observations.
- `source_evidence`: at least one source `path:line` cite, or an explicit `source_unavailable` record when the candidate is to rerun or restore a missing source.
- `ship_flow_baseline`: at least one ship-flow `path:line` cite unless status is `rejected` with `fit_score: no-evidence`.
- `proposed_change`: one concrete change, not a bundle.
- `hermeticity_note`: explains why the change does not add a runtime dependency on the source system.
- `verification_idea`: concrete command, grep, fixture, or reviewer check a future entity can use.
- `proposed_followup`: todo/entity draft text suitable for captain review. Use `proposed_followup: null` only for `already-owned` records where no follow-up should be filed.
- `status`: one of `proposed`, `filed`, `rejected`, or `already-owned`.

## Filing Rules

Default mode stores candidates in the distillation report only.

`--file-todos` mode may write `docs/ship-flow/todos/<slug>.md` for high/medium candidates. It must use explicit pathspec staging/committing when a commit is made. It must not mutate ROADMAP, stage skills, `lib/`, PRODUCT, ARCHITECTURE, or INVARIANTS as part of candidate filing unless a separate approved entity says so.

Todo files must use the established todo frontmatter contract:

```yaml
---
tid: <slug>
captured_at: <UTC timestamp>
status: pending
domain: <optional-domain>
guess_files: []
suggest_done_type: <code|doc|code+doc|research>
entity: null
---
```

Rejected alternatives stay in `## Rejected Imports`. Patterns already present in ship-flow are marked `already-owned` and cited to their ship-flow-owned files.

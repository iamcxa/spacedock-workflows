---
name: debrief-guardrail-harvest
description: "Classify rough PR/debrief lessons into durable guardrail artifacts when the friction is repeatable"
version: 0.1.0
---

# Debrief Guardrail Harvest

Debrief is the point where ship-flow decides whether a rough delivery path
should become a durable guardrail. Do not leave repeatable PR review, CI, or
workflow friction as chat memory.

## Hook: debrief

Run after the normal debrief summary is drafted and before the debrief artifact
is committed.

Inputs:

- PR timeline: review rounds, fix commits, stale-head events, CI reruns, merge
  blockers, and reviewer identities.
- Review findings: external reviewer comments and which findings survived
  deterministic triage.
- Local evidence: commands that could have caught the issue before review.
- Changed files: `_mods/`, workflow README, `spacebridge.yaml`, scripts, config,
  generated artifacts, workflow YAML, seeds, migrations, and project config.

## Classification

| Bucket | When | Artifact |
| --- | --- | --- |
| Mechanical | Regex, parser, diff, generated artifact, or command can decide it. | Script/linter/checker. |
| Semi-mechanical | File signals can trigger a project-specific command. | Ship-flow config + project checker. |
| Skill/mod | Judgment or orchestration is needed, but the path repeats. | `_mods/*.md` or plugin skill. |
| Workflow SOT | The flow failed to discover a rule or hook. | README, stage skill, invariant, or supported Spacebridge manifest field. |
| Todo/entity | Valid but too large or not yet proven. | `docs/<wf>/todos/*.md` or a new entity. |
| No action | One-off incident, external outage, or already-covered guardrail. | Mention in debrief only. |

## Required Section

When a debrief includes review-loop churn, CI reruns, stale-head problems, or
workflow surprise, include:

```md
## Guardrail Harvest

| Friction | Repeatable? | Mechanical? | Proposed Artifact | Owner |
| --- | --- | --- | --- | --- |
| ... | yes/no | yes/partial/no | script/config/mod/todo/no-action | ship-flow/project |
```

If the proposed artifact is `script`, `config`, `mod`, or `Workflow SOT`, the
debrief must link to the PR that added it or create a follow-up todo/entity.

## Guardrail Rules

- Do not write only "remember next time" for repeatable issues.
- Do not add a skill when deterministic lint can enforce the rule.
- Do not put adopter-specific seed, migration, env, or generated-artifact logic
  into the generic plugin. Use a project checker wired through config.
- Do not add a checker that nobody runs. Update the relevant hook or stage
  skill in the same PR.

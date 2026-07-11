# Harvest Vocabulary — Decision Record

- **Status**: accepted
- **Date**: 2026-07-12
- **Deciders**: agent-authored (entity `1-self-adoption-dogfood-bootstrap`, child 1.3), per captain AC-4

## Summary

Ship-flow's harvest lifecycle spans three points in time — debrief-time
triage, review-time adjudication, and cross-project skill evolution — each
with its own vocabulary. Read in isolation, "promoted", "Mechanical", and
"D1" look like competing taxonomies; they are not. This record pins the
correspondence so a reader landing at any one of the three does not have to
reverse-engineer the mapping.

| `debrief-guardrail-harvest` bucket (debrief-time) | `harvest-decide` outcome (review-time) | kc-plugin-forge D-layer (cross-project) |
| --- | --- | --- |
| Mechanical (regex/parser/diff/command can decide it) | `promoted` / `merged-into-canon` | D1 (cross-project canon) |
| Semi-mechanical (file signal triggers a project-specific command) | `promoted` / `merged-into-canon` (as project checker config) | D2 (project-specific) |
| Skill/mod (judgment/orchestration needed, path repeats) | `promoted` / `merged-into-canon` | D1 |
| Workflow SOT (flow failed to discover a rule or hook) | `promoted` | D1 |
| Todo/entity (valid but too large or unproven) | `kept-as-draft-memory` (until the entity ships) | D2 |
| No action (one-off incident, external outage, already covered) | `discarded` | — (not promoted anywhere) |

## How to read this

- **Debrief-time** (`debrief-guardrail-harvest`, hooked into the debrief
  stage) classifies a single PR's friction into one of six buckets, deciding
  what KIND of artifact the friction deserves (script, config, mod, doc, todo,
  or nothing).
- **Review-time** (`harvest-decide`, the T1-3 success-mode lifecycle closer)
  adjudicates candidates captured in a shipped entity's `review.md` (`## What
  Worked` / `## What Almost Failed`) against the same four canon-mutation
  outcomes, using the global MEMORY Quality Rubric (6 gates) as the judgment
  standard.
- **Cross-project** (kc-plugin-forge's D1/D2 layering) classifies where a
  promoted artifact should physically live once it is decided to be canon:
  D1 for patterns generic enough to belong in the shared plugin, D2 for
  patterns that are real and reusable but scoped to one adopting project.

A single friction item threads all three: debrief classifies it Mechanical,
review-time decides `promoted`, and D1/D2 decides whether it lands in
`plugins/ship-flow/` or a project's own `.claude/ship-flow/` config.

## References

- `_mods/debrief-guardrail-harvest.md` §Classification (the six buckets).
- `skills/harvest-decide/SKILL.md` §3 "Decide one outcome per candidate"
  (the four outcomes + MEMORY Quality Rubric judgment standard).
- kc-plugin-forge `reference/skill-evolution.md` (D1/D2 layer definitions;
  external plugin, cited for cross-reference — not vendored into this repo).

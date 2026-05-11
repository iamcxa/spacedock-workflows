# Plan Loose Receipt Fixture

## Context Routing Receipt

| Manifest row | Plan task skill mapping | Reviewer questions | domain_acceptance_checklist row |
|---|---|---|---|
| `domain_matches: schema` | Present in prose only. | Missing concrete reviewer question mapping. | Missing concrete checklist mapping. |

<!-- section:context-routing-manifest -->
```yaml
context-routing-manifest:
  schema_version: 1
  domain_matches:
    - domain: schema
      required: true
  knowledge_modules:
    - domain: schema
      path: plugins/ship-flow/references/domain-knowledge/schema.md
      load_required: false
      missing_behavior: warn
  required_skills:
    - skill: project-db
      source: local-registry
  stage_hints:
    plan:
      - project-db
    execute:
      - fmodel
    verify:
      - project-db
  consumer_obligations:
    plan:
      - map manifest rows to tasks[].skills_needed, reviewer_questions, and domain_acceptance_checklist
```
<!-- /section:context-routing-manifest -->

### Hand-off to Execute

#### domain_acceptance_checklist

| Task ID | Verify Lens | Reviewer Question | Affected Path Family | Required Skills | Evidence Required |
|---|---|---|---|---|---|
| T1 | schema | Does the schema manifest row map to plan receipt and verify lenses? | `plugins/ship-flow/**` | `project-db,test` | Extracted context-routing-manifest block. |

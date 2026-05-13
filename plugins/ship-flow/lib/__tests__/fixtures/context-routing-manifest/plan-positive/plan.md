# Plan Positive Fixture

## Context Routing Receipt

| Manifest row | Plan task skill mapping | Reviewer questions | domain_acceptance_checklist row |
|---|---|---|---|
| `schema_version: 1` | T1 records the schema version contract. | T1 asks whether the schema version remains accepted. | DAC-0 `schema_version` lens checks manifest compatibility. |
| `domain_matches: schema` | T1 includes `skills_needed: ["test", "project-db"]`. | T1 asks whether schema routing is represented. | DAC-1 `schema` lens checks the manifest row. |
| `knowledge_modules: schema` | T1 links the schema module path as optional supporting context. | T1 asks whether knowledge module loading remains warning-only. | DAC-1 `schema` lens checks the knowledge module row. |
| `required_skills: project-db` | T1 maps `project-db` to `skills_needed`. | T1 asks whether required skill rows are preserved. | DAC-2 `project-db` lens checks skill routing. |
| `stage_hints.plan: project-db` | T1 maps the plan hint to `skills_needed`. | Reviewer questions ask whether plan hints survive handoff. | DAC-2 `project-db` lens checks stage hint routing. |
| `consumer_obligations.plan` | T1 maps the obligation to `tasks[].skills_needed` and `reviewer_questions`. | T1 asks whether receipt rows cover consumer obligations. | DAC-3 `consumer_obligations` lens checks the plan obligation. |

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
      - "Map registry rows to task skills and reviewer questions."
    verify:
      - "Extract this block by section tag."
  consumer_obligations:
    plan:
      receipt_section: "## Context Routing Receipt"
      must_create_manifest: true
    verify:
      extraction:
        method: "bash plugins/ship-flow/lib/extract-section.sh <plan.md> context-routing-manifest"
  future_provider_boundary:
    status: optional_append_only
    provider_hints: []
    context_sources:
      - source_type: local-registry
        authoritative_for_routing: true
```
<!-- /section:context-routing-manifest -->

### Hand-off to Execute

#### domain_acceptance_checklist

| Task ID | Verify Lens | Reviewer Question | Affected Path Family | Required Skills | Evidence Required |
|---|---|---|---|---|---|
| T1 | schema | Does the schema manifest row map to plan receipt and verify lenses? | `plugins/ship-flow/**` | `project-db,test` | Extracted context-routing-manifest block and receipt row. |

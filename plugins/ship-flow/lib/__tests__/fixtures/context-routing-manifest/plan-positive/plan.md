# Plan Positive Fixture

## Context Routing Receipt

| Manifest row | Plan task skill mapping | Reviewer questions | domain_acceptance_checklist row |
|---|---|---|---|
| `domain_matches: schema` | T1 includes `skills_needed: ["test", "project-db"]`. | T1 asks whether schema routing is represented. | DAC-1 `schema` lens checks the manifest row. |
| `required_skills: project-db` | T1 maps `project-db` to `skills_needed`. | T1 asks whether required skill rows are preserved. | DAC-2 `project-db` lens checks skill routing. |

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

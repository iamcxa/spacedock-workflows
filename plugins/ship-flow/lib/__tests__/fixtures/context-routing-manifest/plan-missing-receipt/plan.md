# Plan Missing Receipt Fixture

<!-- section:context-routing-manifest -->
```yaml
context-routing-manifest:
  schema_version: 1
  domain_matches:
    - domain: schema
      required: true
  required_skills:
    - skill: project-db
      source: local-registry
  future_provider_boundary:
    status: optional_append_only
    provider_hints: []
```
<!-- /section:context-routing-manifest -->

### Hand-off to Execute

#### domain_acceptance_checklist

| Task ID | Verify Lens | Reviewer Question | Affected Path Family | Required Skills | Evidence Required |
|---|---|---|---|---|---|
| T1 | schema | Does the schema manifest row map to plan receipt and verify lenses? | `plugins/ship-flow/**` | `project-db,test` | Extracted context-routing-manifest block. |

# Verify Positive Plan Fixture

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
  consumer_obligations:
    verify:
      extraction:
        method: "bash plugins/ship-flow/lib/extract-section.sh <plan.md> context-routing-manifest"
  future_provider_boundary:
    status: optional_append_only
    provider_hints: []
```
<!-- /section:context-routing-manifest -->

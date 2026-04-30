# Synthetic Schema Pitch Fixture — Shape Evidence

## Domain Registry Validation
- classify: bash plugins/ship-flow/lib/registry-resolve.sh --classify plugins/ship-flow/lib/__tests__/fixtures/synthetic-schema-pitch/spec.md --adopter-config=plugins/ship-flow/lib/__tests__/fixtures/synthetic-schema-pitch/.claude/ship-flow/domains.yaml
- classify_result: status=ok; matched=schema
- validate: bash plugins/ship-flow/lib/registry-resolve.sh --validate --domain=schema --adopter-config=plugins/ship-flow/lib/__tests__/fixtures/synthetic-schema-pitch/.claude/ship-flow/domains.yaml
- validate_result: status=ok
- domain: schema
- result: proceed

### Hand-off to Design

Use the schema designer specialist because the fixture classifies to
`domain: schema` through local adopter registry evidence. Keep fixture paths
local to ship-flow tests.

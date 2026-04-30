# Synthetic Design Dispatch Fixture - Shape Evidence

## Domain Registry Validation

- classify: bash plugins/ship-flow/lib/registry-resolve.sh --classify plugins/ship-flow/lib/__tests__/fixtures/synthetic-design-dispatch/spec.md --adopter-config=plugins/ship-flow/lib/__tests__/fixtures/synthetic-design-dispatch/.claude/ship-flow/domains.yaml
- result: proceed
- matched: schema
- domain: schema
- affects_ui: true

## Hand-off to Design

Use `ship-design` because the pitch has both UI and schema/domain signals. The
design stage should emit a `design-dispatch-manifest` with a Category A
`ui-designer` lane and a schema `domain-designer` lane, integrated in parallel.

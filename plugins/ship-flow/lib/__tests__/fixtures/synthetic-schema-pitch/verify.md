# Synthetic Schema Pitch Fixture — Verify Evidence

## Intent Match Findings

| Severity | Finding | Evidence | route_to |
|---|---|---|---|
| WARN | Synthetic execute evidence must be checked against schema design intent before real dogfood. | design intent names L1/L2/L3, migration, RBAC, and rebuild checks; execute evidence fixture is intentionally local and non-mutating. | execute |

### Evidence Chain

- Shape evidence resolves `domain: schema` through registry classification.
- Design evidence emits `## Schema Design Output`.
- Verify evidence emits `## Intent Match Findings` and compares design intent to execute evidence.

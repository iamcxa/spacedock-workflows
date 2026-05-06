# fixture: happy-path/shape.md
# Tests: --classify matches schema domain via spec keywords (drizzle + fmodel)
# This spec body intentionally contains trigger keywords for the schema domain.

## Problem

The fmodel L1 decider table needs a new drizzle migration to add an index on `tenant_id`.
We need to update the schema to support multi-tenant lookups efficiently.

## Acceptance

- Migration file created with drizzle schema update
- L2 fstore query updated to use new index

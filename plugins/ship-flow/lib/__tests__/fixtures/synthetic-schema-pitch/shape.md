# Synthetic Schema Pitch Fixture

This fixture represents a carlove-shaped schema pitch while remaining local to
ship-flow tests. It does not read from or write to another repository.

## Problem

Order reconciliation needs a durable schema contract so operational views can
show invoice eligibility without querying event payloads directly.

## Likely files

- domains/orders/src/schema/order.schema.ts
- domains/orders/src/order.table.ts
- domains/orders/src/views/order-read-model.table.ts
- apps/supabase/migrations/202604301130_add_order_reconciliation_columns.sql

## Intent

Update the fmodel contract, drizzle table definition, and migration plan for
the L1 decider, L2 fstore, and L3 view. The design must preserve tenant
ownership, name RBAC subject impact, and document whether an fstore rebuild is
needed before verify compares execute evidence against schema intent.

# Synthetic Schema Pitch Fixture — Shape Evidence

## Domain Registry Validation
- classify: bash plugins/ship-flow/lib/registry-resolve.sh --classify plugins/ship-flow/lib/__tests__/fixtures/synthetic-schema-pitch/shape.md --adopter-config=plugins/ship-flow/lib/__tests__/fixtures/synthetic-schema-pitch/.claude/ship-flow/domains.yaml
- classify_result: status=ok; matched=schema
- validate: bash plugins/ship-flow/lib/registry-resolve.sh --validate --domain=schema --adopter-config=plugins/ship-flow/lib/__tests__/fixtures/synthetic-schema-pitch/.claude/ship-flow/domains.yaml
- validate_result: status=ok
- domain: schema
- result: proceed

### Hand-off to Design

Use the schema designer specialist because the fixture classifies to
`domain: schema` through local adopter registry evidence. Keep fixture paths
local to ship-flow tests.

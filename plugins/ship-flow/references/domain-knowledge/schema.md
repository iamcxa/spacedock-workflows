# Schema Domain

Reference knowledge for ship-flow's schema-domain specialist pipeline.
Read by: ship-design schema-designer | plan architecture-lens | verify intent-match-verifier.

## When This Domain Triggers

**Spec keywords** (case-insensitive match against pitch spec body):
- `schema`, `drizzle`, `fmodel`, `migration`, `column`
- `L1 decider`, `L2 fstore`, `L3 view`

**File-glob patterns** (adopter-configured in `.claude/ship-flow/domains.yaml`):
- Common adopter patterns: `*.fmodel.ts`, `drizzle/**`, `migrations/**`
- Plugin defaults intentionally empty — adopters supply project-specific globs.

## Domain Model

The schema domain covers three layers of the fmodel persistence architecture:

### L1 — Decider (command side)

The authoritative write model. Stores entity state in drizzle tables.

- **Table naming**: `<entity>_store` convention (e.g., `user_store`, `tenant_store`)
- **Primary key**: UUID via `uuid()` default
- **Soft-delete pattern**: `deleted_at TIMESTAMPTZ` column; never hard-delete L1 rows
- **Versioning**: `version INTEGER` column for optimistic concurrency
- **Tenant isolation**: `tenant_id UUID NOT NULL` with index on `(tenant_id, id)`
- **Invariant**: L1 tables are append-friendly; migrations ADD columns, never DROP without deprecation cycle

### L2 — fstore (read-model projections)

Materialized projections derived from L1 events. Read-optimized.

- **Table naming**: `<entity>_fstore_<projection_name>` (e.g., `user_fstore_by_email`)
- **Rebuild semantics**: fstore tables can be fully rebuilt from L1 event log; treat as ephemeral
- **Index strategy**: Each fstore table has a single defining query pattern; optimize for that pattern only
- **Stale tolerance**: fstore reads tolerate eventual consistency (no transaction requirement with L1)

### L3 — View (API surface)

Typed response shapes derived from L2 projections. Not a database concern.

- Lives in domain contract files, not drizzle schema
- Breaking changes to L3 require a new contract version (additive-only within a version)

## Cross-Cutting Concerns

### Event-saga implications

Schema migrations that add/remove L1 columns may require saga compensation logic:
- Adding a nullable column: no saga impact (safe, backward-compatible)
- Adding a NOT NULL column without default: requires data backfill before deploy
- Removing a column: requires saga to stop writing to column first (2-phase: deprecate → remove)

Flag for saga-domain review when: migration drops a column, changes a FK constraint, or alters a PK.

### RBAC subjects

L1 tables holding user-owned resources require `tenant_id` + RBAC subject columns.
New tables touching user data should declare which RBAC subject owns each row.

### Contract surface

Schema changes that alter the shape of L3 view types are breaking API changes.
Coordinate with contract-domain review when L3 types change.

## How to Use This Module

### Mode 1: ship-design schema-designer specialist

Read this module as grounding context before designing the schema output section.
Key questions to answer in `## Schema Design Output`:
1. Which layers (L1/L2/L3) does this pitch touch?
2. Are there event-saga implications for this migration?
3. Does the new/modified table require RBAC subject columns?
4. Is there a L2 fstore rebuild strategy if the migration changes projection shape?

### Mode 2: plan architecture-lens

When schema domain triggers during plan stage, use this module to:
- Identify which L1 tables are affected (cross-check against `## Done Criteria`)
- Flag if saga or RBAC review is needed (add to plan as dependency task)
- Confirm migration is additive-safe (no DROP without deprecation plan)

### Mode 3: verify intent-match-verifier

When checking execute output against design intent, use this module to verify:
- L1 table naming convention followed (`_store` suffix)
- Tenant isolation column present on new tables with user-owned rows
- Migration doesn't drop columns without prior deprecation evidence in plan
- L3 view type changes flagged in Hand-off to Verify if API-breaking

# Synthetic Schema Pitch Fixture — Design Evidence

## Schema Design Output

### Layers touched
- L1 decider: add invoice eligibility fields to the order contract without changing decision identity.
- L2 fstore: add nullable reconciliation columns to the order event repository projection table.
- L3 view: expose the new fields through the order read model view after backfill.

### Migration safety
- Additive / destructive: additive nullable columns only.
- Backfill required: yes, derive initial values from existing order status.
- Event-saga implication: no saga topology change; existing order reconciliation saga reads the new fields after deploy.

### RBAC and tenancy
- tenant_id / ownership columns: preserve existing tenant_id and account_owner_id columns on touched tables.
- RBAC subject: order reconciliation remains guarded by the order:read subject.

### Projection / fstore rebuild
- Rebuild strategy: run a bounded fstore rebuild for order read models after migration.
- Stale-read tolerance: stale eligibility is acceptable until rebuild completes.

### Hand-off constraints for Plan
- Required plan DCs: migration is additive, tenant ownership is preserved, L1/L2/L3 paths are covered.
- Verify-time intent checks: compare execute evidence against L1/L2/L3, migration, RBAC, and rebuild decisions.

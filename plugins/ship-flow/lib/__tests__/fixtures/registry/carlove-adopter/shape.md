# Carlove Schema Pitch Smoke Fixture

This pre-dogfood fixture represents a carlove schema pitch without reading or
writing the real carlove repository.

Files likely touched:
- domains/orders/src/schema/order.schema.ts
- domains/orders/src/order.table.ts
- apps/supabase/migrations/202604300930_add_order_schema.sql

The work updates the fmodel contract, drizzle schema, and migration sequencing
for L1 decider, L2 fstore, and L3 view consistency.

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

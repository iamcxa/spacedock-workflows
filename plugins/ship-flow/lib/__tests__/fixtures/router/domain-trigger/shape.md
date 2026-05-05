# Fixture spec — Domain trigger path (schema domain)

## Problem

New drizzle migration needed for the orders table. fmodel L1 decider requires schema update.
Migration adds column to support L2 fstore projection.

## Acceptance Outcome

Schema migrated cleanly with drizzle; fmodel L1/L2 wiring updated.

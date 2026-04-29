# fixture: m3-partial-coverage/spec.md
# Tests: M3 path — spec body triggers both schema domain and saga domain keywords
# Expected: partial_coverage, matched=schema, missing=saga

## Problem

We need to add a drizzle schema migration and wire up the event saga dispatch
for the new tenant provisioning flow.

## Acceptance

- Schema table created (drizzle migration)
- Saga event dispatched on tenant creation

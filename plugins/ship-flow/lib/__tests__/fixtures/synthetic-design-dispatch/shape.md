# Synthetic Design Dispatch Fixture

This fixture represents a CRM-like UI plus schema pitch while remaining local to
ship-flow tests. It does not read from or write to another repository.

## Problem

Operations needs a new CRM workspace where account managers can see lead status,
next follow-up, owner, and qualification health without switching between
appointment and customer tools.

## Likely files

- apps/web/app/crm/page.tsx
- apps/web/app/crm/components/lead-table.tsx
- apps/web/app/crm/components/lead-detail-panel.tsx
- domains/crm/src/schema/lead.schema.ts
- domains/crm/src/domain/lead/decider.ts
- domains/crm/src/domain/lead/view.ts
- apps/supabase/migrations/202604301530_add_crm_leads.sql

## Intent

Create the first CRM surface, so this is Category A UI work: net-new design
system extension, information architecture, tokens, component specimens, and a
composed CRM mockup are required. The backend/domain lane updates the schema,
fmodel decider, and view projection so plan and execute workers load
`project-db` and `fmodel` skills.

# Synthetic Design Dispatch Fixture - Shape Evidence

## Domain Registry Validation

- classify: bash plugins/ship-flow/lib/registry-resolve.sh --classify plugins/ship-flow/lib/__tests__/fixtures/synthetic-design-dispatch/shape.md --adopter-config=plugins/ship-flow/lib/__tests__/fixtures/synthetic-design-dispatch/.claude/ship-flow/domains.yaml
- result: proceed
- matched: schema
- domain: schema
- affects_ui: true

## Hand-off to Design

Use `ship-design` because the pitch has both UI and schema/domain signals. The
design stage should emit a `design-dispatch-manifest` with a Category A
`ui-designer` lane and a schema `domain-designer` lane, integrated in parallel.

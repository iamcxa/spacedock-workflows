# Synthetic Design Dispatch Fixture - Plan Evidence

## Tasks

### Task 1 - CRM UI design system extension

**Files:** apps/refine-app/src/pages/crm/leads/list.tsx, apps/refine-app/src/pages/crm/leads/components/LeadTable.tsx
**Skills needed:** {skills_needed: ["frontend-design", "refine-expert", "refine-gotchas", "antd-expert", "react-patterns", "tailwind-expert", "react-query-v5", "project-auth", "api-guide", "test"]}
**Folder guidance:** folder_guidance_files=apps/refine-app/CLAUDE.md; folder_guidance_skills=refine-expert,antd-expert,react-query-v5,project-auth,api-guide,refine-gotchas

### Task 2 - CRM schema and migration

**Files:** domains/crm/src/schema/lead.schema.ts, apps/supabase/migrations/202604301530_add_crm_leads.sql
**Skills needed:** {skills_needed: ["project-db", "fmodel", "test"]}

### Task 3 - CRM fmodel projection

**Files:** domains/crm/src/domain/lead/decider.ts, domains/crm/src/domain/lead/view.ts
**Skills needed:** {skills_needed: ["fmodel", "test"]}

## Plan Report

skill-coverage: PASS
design-routing-propagation: PASS

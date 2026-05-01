# Synthetic Design Dispatch Fixture - Design Evidence

design-dispatch-manifest:
  lanes:
    - lane: ui
      role: ui-designer
      category: Category A
      required_skills:
        - design-flow
        - design-brief
        - information-architecture
        - design-tokens
        - brief-to-tasks
        - frontend-design
        - design-review
        - refine-expert
        - refine-gotchas
        - antd-expert
        - react-patterns
        - tailwind-expert
      adopter_routing:
        files:
          - apps/refine-app/src/pages/crm/leads/list.tsx
        skills_needed: refine-expert,refine-gotchas,antd-expert,react-patterns,tailwind-expert
        folder_guidance_files: apps/refine-app/CLAUDE.md
        folder_guidance_skills: refine-expert,antd-expert,react-query-v5,project-auth,api-guide,refine-gotchas
        codex_context_boundary: root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files
      outputs:
        - plugins/example/design/design-system.md
        - plugins/example/design/tokens.css
        - plugins/example/design/components/crm-lead-table.html
        - plugins/example/design/crm-workspace.html
      whole_page_visual_targets:
        - route: /crm/leads
          reference_artifact: plugins/example/design/crm-workspace.html
          capture: full-page screenshot
          threshold: "warn>1%, block composition mismatch"
          rationale_decision: D1
    - lane: domain
      role: domain-designer
      domain: schema
      required_skills:
        - project-db
        - fmodel
      knowledge_module_path: plugins/ship-flow/references/domain-knowledge/schema.md
      designer_section_anchor: ship-design#schema-designer
      outputs:
        - "## Schema Design Output"
  integration:
    mode: parallel
    owner: ship-design

## UI Design Output

### Category A skill chain

The UI lane uses `design-brief`, `information-architecture`, `design-tokens`,
`brief-to-tasks`, `frontend-design`, and `design-review` to establish a new CRM
workspace pattern.

### Context Read Receipt

- guidance files: apps/refine-app/CLAUDE.md
- routed skills: refine-expert, refine-gotchas, antd-expert, react-patterns, tailwind-expert
- folder guidance skills: refine-expert, antd-expert, react-query-v5, project-auth, api-guide, refine-gotchas
- applied constraints: use Refine/AntD patterns, keep ProCRUD as the unified CRUD surface, and define data access through Refine hooks before plan slicing.

### Hand-off constraints for Plan

- Preserve dense CRM table scanning.
- Include a lead detail panel specimen.
- Verify token reuse through CSS custom properties.

whole_page_visual_targets:
- route: /crm/leads
  reference_artifact: plugins/example/design/crm-workspace.html
  capture: full-page screenshot
  threshold: "warn>1%, block composition mismatch"
  rationale_decision: D1

## Design Readiness Review

risk_trigger: multi-domain
reviewers: ui, schema
verdict: PASS
findings:
- reviewer: ui
  severity: PASS
  route_to: plan
  evidence: plugins/example/design/crm-workspace.html
- reviewer: schema
  severity: PASS
  route_to: plan
  evidence: "## Schema Design Output"

## Schema Design Output

### Layers touched
- L1 decider: add lead qualification fields to the CRM lead aggregate.
- L2 fstore: persist lead status and next follow-up snapshot.
- L3 view: expose CRM lead table rows.

### Migration safety
- Additive / destructive: additive table and nullable columns.
- Backfill required: yes, derive initial rows from existing customer records.
- Event-saga implication: no topology change; appointment follow-up saga reads CRM projection after deploy.

### RBAC and tenancy
- tenant_id / ownership columns: required on new CRM lead table.
- RBAC subject: crm:read and crm:write.

### Projection / fstore rebuild
- Rebuild strategy: bounded rebuild for CRM lead view.
- Stale-read tolerance: stale follow-up status is acceptable until rebuild completes.

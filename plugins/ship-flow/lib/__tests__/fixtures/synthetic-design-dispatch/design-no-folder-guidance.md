# Synthetic Design Without Folder Guidance

design-dispatch-manifest:
  lanes:
    - lane: ui
      role: ui-designer
      category: Category D
      required_skills:
        - frontend-design
        - react-patterns
      adopter_routing:
        files:
          - apps/plain-web/src/pages/home.tsx
        skills_needed: frontend-design,react-patterns
        folder_guidance_files:
        folder_guidance_skills:
        codex_context_boundary: root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files
      outputs: []
  integration:
    mode: single-designer
    owner: ship-design

## UI Design Output

### Context Read Receipt

- guidance files: none — resolver reported no folder_guidance_files
- routed skills: frontend-design, react-patterns
- folder guidance skills: none
- applied constraints: use local component conventions from inspected files.

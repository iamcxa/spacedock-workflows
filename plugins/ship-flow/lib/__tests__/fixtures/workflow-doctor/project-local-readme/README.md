---
commissioned-by: spacedock@0.10.1
entry-point: ship-flow:ship-shape
entity-type: feature
entity-label: feature
entity-label-plural: features
id-style: slug
stages:
  defaults:
    worktree: true
    concurrency: 2
  states:
    - name: draft
      initial: true
      worktree: false
    - name: shape
      worktree: false
      gate: true
      manual: true
      skill: ship-flow:ship-shape
      model: opus
    - name: design
      worktree: true
      gate: true
      manual: conditional
      skill: ship-flow:ship-design
      model: opus
    - name: plan
      skill: ship-flow:ship-plan
      model: sonnet
    - name: execute
      skill: ship-flow:ship-execute
      model: sonnet
    - name: verify
      gate: true
      worktree: false
      skill: ship-flow:ship-verify
      model: sonnet
      dispatch: debate-driven
      feedback-to: execute
    - name: ship
      worktree: false
      skill: ship-flow:ship-review
      model: sonnet
    - name: done
      terminal: true
      worktree: false
  transitions:
---

# Ship-Flow Pipeline

## Local Operating Notes

This adopter keeps repository-specific escalation notes here. The doctor should
identify this as project-local README content, not as a sync blocker.

### 3 user-invocable entries

| Command | Input | Output artifact | Human in loop? |
|---|---|---|---|
| `/shape <concept | issue | vague>` | directive or entity id | `<entity-folder>/spec.md` | YES |
| `/ship <entity-id | requirement>` | entity-id OR concrete req | stage artifacts + code | NO after shape |
| `/verify <entity-id | requirement>` | entity-id or req | `verify.md` | NO unless BLOCKING |
| `/add-todos <idea>` | free text | todo entry | NO |

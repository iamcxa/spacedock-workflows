---
commissioned-by: spacedock@0.9.0
entry-point: ship-flow:ship-shape
entity-type: feature
entity-label: feature
entity-label-plural: features
id-style: sequential
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
      skip-when: "!affects_ui"
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

Older adopter README body.

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
      parallelism: probes
      skill: ship-flow:ship-shape
      model: opus
    - name: design
      worktree: true
      gate: true
      manual: conditional
      parallelism: lanes
      skip-when: "!affects_ui && !domain && !design_required"
      skill: ship-flow:ship-design
      model: opus
    - name: plan
      parallelism: draft-lanes
      skill: ship-flow:ship-plan
      model: sonnet
    - name: execute
      parallelism: dag
      skill: ship-flow:ship-execute
      model: sonnet
    - name: verify
      gate: true
      worktree: false
      parallelism: checks
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

docs/ship-flow/<id>-<slug>/
  design.md     # ship-design output — UI/domain design intent, visual targets, handoff to plan, design-dispatch-manifest
  plan.md       # ship-plan output — task breakdown, tdd_contract, verification spec, DC, plan-parallelization-manifest
  execute.md    # ship-execute output — commits, files modified, RED-before-GREEN evidence, UAT evidence, execute-dispatch-manifest
  verify.md     # ship-verify output — quality gate, review, TDD evidence audit, UAT, verdict, verify-check-manifest

### Parallelism Contract

Ship-flow uses stage-internal parallelism only; the stage chain remains serial
because each stage defines the next stage's contract. Each parallel stage has a
single integrator.

**verify reviewer panel lane:** Plan turns domain/framework `skills_needed` into
task-level `reviewer_questions` and a hand-off `domain_acceptance_checklist`;
verify consumes those rows when building the verify reviewer panel.

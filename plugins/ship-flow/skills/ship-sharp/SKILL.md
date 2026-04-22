---
name: ship-sharp
description: "DEPRECATED alias — use when a caller still invokes ship-flow:ship-sharp after the Phase 2 rename. Silently forwards to ship-flow:ship-shape with identical arguments. Scheduled for removal one release cycle after Phase 2 ships."
user-invocable: true
argument-hint: "[directive-text | todo-tid | entity-id]"
---

# ship-sharp — DEPRECATED alias

**This skill is a back-compat alias.** The ship-flow sharpening stage was renamed `sharp` → `shape` in Phase 2 of the ship-flow distillation. All logic now lives in `ship-flow:ship-shape`.

Use `ship-flow:ship-shape` directly for new work. This alias exists only so callers and docs referencing the old name continue to work for one release cycle.

## Behavior

Invoke `ship-flow:ship-shape` with the same arguments that were passed here. Do **not** inspect the argument, do **not** read entity frontmatter, do **not** branch on directive shape — forwarding is unconditional. The target skill's Step 1 intake handles all input forms (free text, todo tid, entity id) and all edge cases (escape hatch, shaped-child rejection).

```
Skill("ship-flow:ship-shape") with the same arguments passed to this alias.
```

After the forward, exit. Do not add any additional behavior in this skill.

## Why the rename

- **`sharp`** framed the stage as Musk-style sharpening of an already-formed directive.
- **`shape`** aligns with Shape Up methodology — the stage now produces a pitch proposal (problem + appetite + vertical-slice children + rabbit holes + Musk deletes + DAG), which is the shaping artifact in Shape Up.

The autonomous-proposer redesign (Phase 2 Task 2.2) is the substantive change; the rename is the vocabulary it brings with it.

## Removal timeline

This alias is scheduled for removal one release cycle after Phase 2 ships. Migration path for callers:

- Replace `Skill("ship-flow:ship-sharp")` with `Skill("ship-flow:ship-shape")`.
- Replace `ship-flow:ship-sharp` strings in `workflow-template.yaml`, `docs/*/README.md` frontmatter (`entry-point:`), and any hook / settings JSON.
- Replace `/sharp` with `/shape` in captain-facing documentation.

When the alias is removed, any remaining references to `ship-flow:ship-sharp` will fail skill resolution.

## References

- Spec: `docs/superpowers/specs/2026-04-22-ship-flow-distillation-phase-2.md` Task 2.6.
- Replacement skill: `plugins/ship-flow/skills/ship-shape/SKILL.md`.

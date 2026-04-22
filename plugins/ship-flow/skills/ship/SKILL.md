---
name: ship
description: "Entry-point skill for the ship-flow pipeline. Phase 2 stub: routes existing sharp entities through plan→execute→verify→review; Phase 3 will add todo-promotion and free-text auto-shape routing. Use /ship-shape for new directives; use /add-todos for quick idea capture."
user-invocable: true
argument-hint: "<entity-id-or-slug>"
---

# Ship — Pipeline Entry Point (Phase 2 Stub)

You are running the SHIP entry point. Your job is to classify the argument and route to the correct handler.

**Phase 2 routing table:**

| Argument form | Phase 2 action |
|---------------|----------------|
| Existing entity id/slug (`docs/ship-flow/<id>-<slug>.md` exists) | Advance through pipeline (see below) |
| Todo id (`docs/ship-flow/todos/<tid>.md` exists) | Fail with Phase 3 message |
| Free-text directive (quoted string, no matching file) | Fail with Phase 3 message |

## Step 1 — Classify argument

Given argument `<arg>`:

1. **Entity check**: Does `docs/ship-flow/<arg>.md` exist? Or does any file match `docs/ship-flow/<arg>-*.md` or `docs/ship-flow/*-<arg>.md`? If yes → **entity path**.
2. **Todo check**: Does `docs/ship-flow/todos/<arg>.md` exist? If yes → **todo path**.
3. Otherwise → **free-text path**.

## Step 2a — Entity path (existing sharp entity)

Forward to the ship-flow pipeline in order:

1. `ship-flow:ship-plan` — generate task plan for the entity
2. `ship-flow:ship-execute` — execute tasks
3. `ship-flow:ship-verify` — run DCs / quality checks
4. `ship-flow:ship-review` — code review + captain smoke gate
5. Merge when captain approves

Report each stage result to captain as it completes.

## Step 2b — Todo path (NOT YET IMPLEMENTED)

Print and stop:

```
/ship <todo-id> is not yet supported in Phase 2.

Phase 3 will add todo-to-entity promotion (auto-shape from captured todo).
For now, promote manually:
  1. Run /ship-shape <todo-id> to convert the todo into a shaped pitch.
  2. Confirm the pitch proposal.
  3. Re-run /ship <entity-id> once the shaped entity exists.
```

Exit without running any pipeline stages.

## Step 2c — Free-text directive (NOT YET IMPLEMENTED)

Print and stop:

```
/ship "<directive>" is not yet supported in Phase 2.

Phase 3 will add /ship <directive> with auto-shape routing.
For now:
  - Use /ship-shape "<directive>" to shape it into a pitch first.
  - Or use /add-todos "<directive>" to capture as a rabbit-hole todo for later.
```

Exit without running any pipeline stages.

## Examples

**Existing entity (works now):**
```
captain: /ship 073-turbopack-cache-fix
agent:   Found entity: docs/ship-flow/073-turbopack-cache-fix.md
         Running ship-flow pipeline...
         [ship-plan] → [ship-execute] → [ship-verify] → [ship-review]
```

**Todo id (Phase 3):**
```
captain: /ship filter-chip-multi
agent:   /ship filter-chip-multi is not yet supported in Phase 2.
         Phase 3 will add todo-to-entity promotion...
```

**Free text (Phase 3):**
```
captain: /ship "add dark mode toggle"
agent:   /ship "add dark mode toggle" is not yet supported in Phase 2.
         Phase 3 will add /ship <directive> with auto-shape routing...
```

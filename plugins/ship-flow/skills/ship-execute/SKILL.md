---
name: ship-execute
description: "Use when executing a plan's tasks via ensign dispatch. Agent-autonomous: dispatches per-task agents with model hints, quality check per task, review loop. No captain gate."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Execute — Dispatch and Build

You are running the EXECUTE stage of ship-flow. No captain interaction — dispatch agents for each task, verify each one, handle failures automatically.

## Step 1: Read Plan

Read the entity file. Extract `## Plan` section — parse all tasks with their files, steps, verification commands, and model hints.

Build a task queue:
- Independent tasks can run in parallel (if no file overlap)
- Dependent tasks run sequentially
- Track: task name, status (pending/running/done/failed/blocked), model, files

## Step 2: Execute Tasks

For each task, dispatch an implementation subagent:

```
Agent(
  description: "Task {N}: {name}",
  model: {task.model},  // haiku or sonnet from plan
  prompt: |
    You are implementing one task from a ship-flow plan.

    ## Task
    {full task text from plan}

    ## Context
    Project: {project description}
    Entity: {entity title} — {problem summary}
    {If project skills relevant: "Available skill: {skill} — use it for {purpose}"}

    ## Your Job
    1. Implement exactly what the task specifies
    2. Write tests if the task says to
    3. Run the verification command
    4. If verification passes → commit with descriptive message
    5. If verification fails → fix and retry (max 3 attempts)
    6. Report: DONE | FAILED (with details) | BLOCKED (what you need)

    ## Quality Check (mandatory before reporting DONE)
    Run: bun build 2>&1; tsc --noEmit 2>&1; bun test 2>&1
    All must pass. If any fail, fix before reporting DONE.

    Work from: {project_root}
)
```

## Step 3: Review Each Task

After each task agent reports DONE, dispatch a review subagent:

```
Agent(
  description: "Review Task {N}: {name}",
  model: haiku,  // Reviews are mechanical — haiku is fine
  prompt: |
    Review the changes from Task {N}: {name}.

    ## What was requested
    {task text from plan}

    ## What changed
    Run: git diff HEAD~1 --stat && git diff HEAD~1
    
    ## Check
    1. Does the diff match what the task requested? (no more, no less)
    2. Are there obvious bugs, missing error handling, or broken imports?
    3. Do tests exist for new functionality?
    
    Report: APPROVED | NEEDS_FIX (list specific issues)
)
```

If NEEDS_FIX → dispatch fix agent (same model as original task) with specific issues. Then re-review. Max 3 rounds.

## Step 4: Handle Failures

**Task FAILED (max retries hit):**
- Log to `## Execution Log`
- If task is blocking other tasks → mark dependents as BLOCKED
- If task is independent → skip, create auto-issue entity:
  ```
  Entity: {slug}-fix-{task-N}
  Status: draft
  Source: "auto:ship-flow execute"
  Body: ## Problem\n{failure details}\n## Context\n{original task}
  ```

**Task BLOCKED:**
- Log reason to `## Execution Log`
- If blocker is external (needs captain input) → escalate: set entity status back to `sharp` with `## Execution Log` noting the blocker
- Max 2 escalations per entity → reject entity

## Step 5: Frontend Change Detection

After all tasks complete, check if frontend files were touched:

```bash
git diff {execute_start_sha}..HEAD --name-only | grep -E '^(ui/|app/|components/|pages/|src/.*\.tsx)'
```

If yes → run Tier 2 smoke check:
```bash
# Start dev server, wait for ready, check key routes
timeout 30 bun dev &
sleep 5
curl -sf http://localhost:3000 > /dev/null && echo "T2: root OK" || echo "T2: root FAIL"
# Kill dev server
kill %1 2>/dev/null
```

Log result to `## Execution Log`.

## Step 6: Write Entity Sections

```markdown
## Execution Log

| Task | Model | Status | Files Changed | Retries | Review |
|------|-------|--------|---------------|---------|--------|
| 1: {name} | haiku | done | file1.ts, file2.ts | 0 | approved |
| 2: {name} | sonnet | done | file3.ts | 1 | approved (round 2) |
| 3: {name} | haiku | failed | — | 3 | — |

Frontend smoke: {PASS/FAIL/N/A}

## Issues Found
- Task 3 failed: {details} → auto-created entity #{slug}-fix-3
```

Commit all execute-stage changes:
```bash
git add -A && git commit -m "execute: {entity-slug} — {N} tasks done, {M} failed"
```

## Circuit Breakers

- Per-task retry: max 3
- Per-task review loop: max 3
- Total blocked tasks: > 50% of tasks blocked → escalate to captain
- Token tracking: log each agent dispatch cost to entity frontmatter `token_actual`

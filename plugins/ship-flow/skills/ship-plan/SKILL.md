---
name: ship-plan
description: "Use when writing an implementation plan for a sharpened entity. Agent-autonomous: size-adaptive research, plan generation with self-review loop. No captain gate."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Plan — Research and Plan

You are running the PLAN stage of ship-flow. No captain interaction — you research, write, review, and iterate until the plan is solid enough for agents to execute autonomously.

## Entity Body Contract

**Reads:** `## Problem`, `## Done Criteria`, `## Size Assessment`, `## Project Skills`
**Writes (all mandatory):**
- `## Research Summary` — key findings from researchers, or "Size S — no research needed"
- `## Plan` — tasks with files, steps, verification commands, model hints (haiku/sonnet)
- `## Plan Review` — iterations count, gaps, estimated task count, model split
**Optional writes:**
- `## Learnings` — insights discovered during planning (append-only)

## Step 1: Read Sharp Output

Read the entity file. Extract:
- `## Problem` — what to solve
- `## Done Criteria` — what "shipped" looks like
- `## Size Assessment` — S/M/L determines your approach
- `## Project Skills` — domain skills available

## Step 2: Research (size-adaptive)

### Size S — Skip Research
The problem is clear and small. Go directly to Step 3.

### Size M — Targeted Research
Dispatch 1-2 researcher subagents in parallel:

```
Agent 1: "Explore the codebase for files affected by: {problem}.
  Read existing patterns. Report: affected files, current approach,
  suggested approach. Under 200 words."

Agent 2: "Check library/API constraints for: {relevant tech}.
  Report: version requirements, breaking changes, gotchas. Under 200 words."
```

If project skills are listed in `## Project Skills`, instruct researchers:
"This project has {skill} — check it for existing patterns before proposing new ones."

### Size L — Full Research
Dispatch 3+ researcher subagents:
- Agent 1: Codebase mapping (affected files, dependencies)
- Agent 2: Library/API constraints
- Agent 3: Existing similar implementations in the codebase
- Additional agents per specific unknowns from `## Problem`

Collect all research outputs.

## Step 3: Write Plan

Write a plan with concrete tasks. Each task must be completable by a single agent in one dispatch.

Format:

```markdown
## Research Summary
{Key findings from researchers, or "Size S — no research needed"}

## Plan

### Task 1: {name}
**Files:** {create/modify with paths}
**Steps:**
1. {specific action with code}
2. {test to write}
3. {verification command}
**Done:** {how to verify this task is complete}
**Model:** haiku | sonnet
{haiku for: single-file, clear spec, mechanical}
{sonnet for: multi-file, judgment needed, integration}

### Task 2: {name}
...
```

**Rules:**
- Every task has exact file paths
- Every task has a verification command
- Every task specifies model tier (haiku or sonnet)
- Tasks are ordered by dependency — independent tasks noted for parallel execution
- No placeholders ("add appropriate error handling" = plan failure)
- Code blocks for any non-trivial implementation

## Step 4: Self-Review Loop

After writing the plan, review it yourself:

1. **Coverage**: Does every Done Criterion from `## Done Criteria` map to at least one task?
2. **Completeness**: Can an agent execute each task without asking questions?
3. **Independence**: Can tasks run in parallel where marked? No hidden dependencies?
4. **Model fit**: Are haiku tasks truly mechanical? Are sonnet tasks truly judgment-requiring?

If issues found → fix inline and re-review. Max 3 iterations.

If after 3 iterations the plan still has gaps → write `## Plan Review` noting the gaps and proceed. Execute stage will surface real problems faster than more planning.

## Step 5: Write Entity Sections

```markdown
## Research Summary
{findings}

## Plan
{tasks}

## Plan Review
Iterations: {N}
Gaps: {any remaining, or "none"}
Estimated tasks: {count}
Estimated model split: {N haiku, M sonnet}
```

## Circuit Breaker

- Research subagent timeout: 2 minutes per agent
- Self-review loop: max 3 iterations → proceed with gaps noted
- Total plan stage: if > 15 minutes elapsed → write what you have and proceed

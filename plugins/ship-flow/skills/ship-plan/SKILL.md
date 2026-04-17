---
name: ship-plan
description: "Use when writing an implementation plan for a sharpened entity. Agent-autonomous: size-adaptive research, plan generation with self-review loop. No captain gate."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Plan — Research and Plan

You are running the PLAN stage of ship-flow. No captain interaction — you research, write, review, and iterate until the plan is solid enough for agents to execute autonomously.

## Entity Body Contract

**Reads:** `## Problem`, `## Done Criteria`, `## Size Assessment`, `## Project Skills`, `## Shape Output` (if shape ran), `## Musk Audit`
**Writes (all mandatory):**
- `## Research Summary` — key findings from researchers, or "Size S — no research needed"
- `## Plan` — tasks with files, steps, verification commands, model hints (haiku/sonnet), wave assignments
- `## Plan Review` — iterations count, gaps, estimated task count, model split, plan-checker results
**Optional writes:**
- `## Learnings` — insights discovered during planning (append-only)

## Step 1: Read Sharp Output

Read the entity file. Extract:
- `## Problem` — what to solve
- `## Done Criteria` — what "shipped" looks like
- `## Size Assessment` — S/M/L determines your approach
- `## Project Skills` — domain skills available
- `## Shape Output` — scope in/out (if shape phase ran) — these are your scope anchors
- `## Musk Audit` — gap-to-goal analysis, KEEP/DEFER/DELETE verdicts

**Input validation**: If `## Problem` or `## Done Criteria` is missing, write `## Plan Review` with `status: blocked, reason: missing sharp output` and return. Do NOT plan on partial input.

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
Dispatch 3-5 researcher subagents (capped at 5):
- Agent 1: Codebase mapping (affected files, dependencies, layer classification)
- Agent 2: Library/API constraints
- Agent 3: Existing similar implementations in the codebase
- Agent 4+: Per specific unknowns from `## Problem`

**Research topic domains** (from build-plan):
1. **Upstream Constraints** — project rules that constrain the solution (CLAUDE.md, existing decisions)
2. **Existing Patterns** — how similar problems are already solved (2+ consistent usages)
3. **Library/API Surface** — third-party behavior, version pinning, public API contracts
4. **Known Gotchas** — landmines, race conditions, non-obvious interactions
5. **Reference Examples** — one-shot examples the plan will copy from

**Contradiction handling**: When two researchers return conflicting findings on the same topic, write BOTH findings verbatim in `## Research Summary` as an Open Question. Do NOT silently pick one. Do NOT dispatch a tiebreaker. The contradiction is a first-class output that the plan must address explicitly.

Collect all research outputs.

## Step 2.5: Scope Anchoring (M/L only)

**Skip for Size S.**

Before writing tasks, cross-reference against scope:
- If `## Shape Output` has Scope In → every task must map to a Scope In bullet
- If no Shape Output → every task must map to a `## Done Criteria` item

Produce a mapping table:

```markdown
| Task | Maps to |
|------|---------|
| Task 1 | Done Criteria #1 / Scope In #2 |
| Task 2 | Done Criteria #3 |
```

**Halt condition**: any task with no mapping → drop the task (out of scope) or note a scope gap in `## Plan Review`. Do NOT silently expand scope beyond what sharp defined.

## Step 3: Write Plan

Write a plan with concrete tasks. Each task must be completable by a single agent in one dispatch.

Format:

```markdown
## Research Summary
{Key findings from researchers, or "Size S — no research needed"}
{Any Open Questions from contradictory research — with both findings verbatim}

## Plan

### Task 1: {name}
**Wave:** {0|1|2|...} — wave 0 for test infrastructure, same-wave tasks can run in parallel
**Files:** {create/modify with exact paths}
**Read first:** {files the agent must read before starting}
**Steps:**
1. {specific action with code}
2. {test to write}
3. {verification command}
**Done:** {how to verify this task is complete — runnable command}
**Model:** haiku | sonnet
{haiku for: single-file, clear spec, mechanical}
{sonnet for: multi-file, judgment needed, integration}

### Task 2: {name}
...
```

### Plan Writing Rules (No Placeholders)

Every task must contain the actual content an agent needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without specifying what to test)
- "Similar to Task N" (repeat the specifics — the agent reads tasks independently)
- Steps that describe what to do without showing how
- References to types, functions, or methods not defined anywhere in the plan

### Wave Assignment Rules

- **Wave 0**: test infrastructure creation (setup files, fixtures)
- **Wave N+1** tasks can only depend on outputs from wave ≤ N
- Tasks in the same wave must NOT have `files_modified` overlap (parallel safety)
- A wave N task's `read_first` cannot include a file first written by another wave N task

### Task Verification Rules

Every task's **Done** field must contain a runnable command:
```
Done: `bun test tests/x.test.ts` passes
Done: `grep "validateEmail" src/models/User.ts` finds the new function
```
Not: "works correctly" / "is properly implemented" / "handles all cases"

## Step 4: Self-Review Loop (Plan-Checker Lite)

After writing the plan, run this multi-dimensional review:

### Dimension 1 — Requirement Coverage
Does every Done Criterion from `## Done Criteria` map to at least one task? Missing coverage = blocker.

### Dimension 2 — Task Completeness
Does every task have: exact file paths, verification command, model hint, wave assignment? Missing fields = blocker.

### Dimension 3 — Dependency Correctness
Build the wave graph. Check:
- Wave N `read_first` only references wave < N outputs or pre-existing files
- No `files_modified` overlap within the same wave
- No cycles

### Dimension 4 — Zero-Placeholder Scan
Grep the plan for: `TBD`, `add appropriate`, `similar to Task N`, `as needed`, `fill in`, `...`. Any hit = fix it inline.

### Dimension 5 — Type/Signature Consistency
If task-3 introduces a function signature and task-5 calls it, the signatures must match. Cross-task inconsistency = blocker.

### Dimension 6 — Task Minimality (M/L only)
For each task, ask:
1. Could this merge with an adjacent task without losing ship-worthiness?
2. Is this scaffolding (setup, imports, empty files) that should collapse into the task that uses it?
3. Are there nice-to-haves not in Done Criteria? Drop them.

**Fix issues inline.** Then re-review. Max 3 iterations.

If after 3 iterations the plan still has blocker-level gaps → write `## Plan Review` with `status: gaps-noted` and proceed. Execute stage will surface real problems faster than more planning.

## Step 5: Write Entity Sections

```markdown
## Research Summary
{findings, or "Size S — no research needed"}
{Open Questions from contradictory research, if any}

## Plan
{tasks with wave assignments}

## Plan Review
Iterations: {N}
Status: {clean | gaps-noted}
Dimensions checked: {list which passed/failed}
Gaps: {any remaining, or "none"}
Scope anchoring: {all tasks mapped | gaps noted}
Estimated tasks: {count}
Estimated model split: {N haiku, M sonnet}
```

## Circuit Breakers

- Research subagent timeout: 2 minutes per agent
- Self-review loop: max 3 iterations → proceed with gaps noted
- Total plan stage: if > 15 minutes elapsed → write what you have and proceed
- Research contradictions: write both, never silently resolve, never dispatch tiebreaker

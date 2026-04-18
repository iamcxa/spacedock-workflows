---
name: ship-plan
description: "Use when writing an implementation plan for a sharpened entity. Agent-autonomous: size-adaptive research with produce+review team, TDD task structure, plan reviewed by separate agent. No captain gate."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Plan — Research and Plan

You are running the PLAN stage of ship-flow. No captain interaction — you research, write, review, and iterate until the plan is solid enough for agents to execute autonomously.

## Entity Body Contract

**Schema:** `references/entity-body-schema.yaml` → `stages.plan`

**Reads:** `## Sharp Output` (all subsections), `PRODUCT.md` (architecture + constraints)
**Writes:**
- `## Plan Output` — subsections: Research Summary, Size Re-evaluation, Verification Spec, Plan (TDD tasks with waves)
- `## Plan Report` — status, stage_cost, iterations, dimensions, reviewer verdict, scope anchoring, task count, model split

## Step 1: Read Sharp Output

Read the entity file. Extract:
- `## Problem` — what to solve
- `## Done Criteria` — what "shipped" looks like
- `## Size Assessment` — S/M/L determines your INITIAL approach (may change after research)
- `## Project Skills` — domain skills available
- `## Shape Output` — scope in/out (if shape phase ran) — these are your scope anchors
- `## Musk Audit` — gap-to-goal analysis, KEEP/DEFER/DELETE verdicts

Also read `PRODUCT.md` if it exists — check `## Architecture` and `## Constraints` for solution constraints.

**Input validation**: If `## Problem` or `## Done Criteria` is missing, write `## Plan Review` with `status: blocked, reason: missing sharp output` and return. Do NOT plan on partial input.

## Step 1.5: Assumption Re-Validation

Sharp-stage assumptions may reference codebase state that changed between sharp and plan (other merges, concurrent work, manual edits). Before planning, verify that sharp's evidence still holds.

**Procedure:**

1. Scan `## Musk Audit` and `## Shape Output` (if exists) for file:line citations — any reference of the form `path/to/file.ts:NN` or `path/to/file.ts lines NN-MM`.
2. For each citation, Read the file at the cited line range.
3. Compare current content against what sharp assumed:

| Result | Action |
|--------|--------|
| Evidence holds — content supports the assumption | Proceed silently |
| Evidence stale — line shifted but claim still plausible | Note `(⚠ stale-evidence: {file}:{line})` inline, proceed with caution |
| Evidence contradicted — content shows the opposite | **BLOCKER** — write `## Plan Review` with `status: blocked, reason: sharp assumption contradicted` and return. Do NOT plan on stale premises. |

**Skip when:** No file:line citations found in sharp output (common for S-size entities with simple directives). Log "Step 1.5: skipped — no file:line citations in sharp output" and proceed.

**Why this matters:** Planning on stale assumptions is the most expensive failure mode — the plan looks correct, execute dispatches agents, and tasks BLOCK because the codebase doesn't match what the plan expected. One Read per citation at plan start costs seconds; a stale-assumption BLOCKED task costs minutes + escalation ladder.

## Step 2: Research (size-adaptive, produce+review team)

### Size S — Skip Research
The problem is clear and small. Go directly to Step 2.7.

### Size M — Targeted Research (2 agents: produce + review)

**Agent A (Producer)** — dispatch as subagent:

```
Agent(
  description: "Research: {problem summary}",
  model: sonnet,
  prompt: |
    Research two topics for planning. Report findings with file:line citations.

    ## Topic 1: Codebase Impact
    Explore the codebase for files affected by: {problem}.
    Read existing patterns. Report: affected files with paths, current approach,
    dependencies, suggested approach.

    ## Topic 2: Library/API Constraints
    Check library/API constraints for: {relevant tech}.
    Report: version requirements, breaking changes, gotchas.

    {If project skills: "This project has {skill} — load it and check for existing patterns."}

    ## Output Format
    For each topic: 3-5 bullet findings, each with file:line citation.
    Flag any contradictions between topics.
    Under 400 words total.
)
```

**Agent B (Reviewer)** — dispatch AFTER Agent A returns:

```
Agent(
  description: "Review research: {problem summary}",
  model: sonnet,
  prompt: |
    Review these research findings for a plan about: {problem}

    ## Research Findings
    {Agent A's full output}

    ## Review Checklist
    1. Are file:line citations real? (spot-check 2-3 by reading the actual files)
    2. Are there codebase areas the research MISSED? (check imports, callers, tests)
    3. Do the findings contradict each other? (flag explicitly)
    4. Is the "suggested approach" feasible given the constraints?
    5. What's the actual file count that would change? (for size re-evaluation)

    Report:
    - APPROVED: findings are solid
    - GAPS: {list specific gaps to investigate}
    - CONTRADICTION: {list conflicting findings}

    Under 300 words.
)
```

If GAPS → dispatch Agent A again with specific gap questions. Max 1 round.

### Size L — Full Research (3+ producers + 1 reviewer)

Dispatch 3-5 producer subagents in parallel (capped at 5), each covering one domain:

1. **Upstream Constraints** — project rules (CLAUDE.md, existing decisions, PRODUCT.md constraints)
2. **Existing Patterns** — how similar problems are already solved (2+ consistent usages)
3. **Library/API Surface** — third-party behavior, version pinning, public API contracts
4. **Known Gotchas** — landmines, race conditions, non-obvious interactions
5. **Reference Examples** — one-shot examples the plan will copy from

Each producer: sonnet, under 200 words, file:line citations mandatory.

**Reviewer** — dispatch AFTER all producers return:

Same review checklist as M-size, plus:
- Cross-domain consistency check (does the constraint researcher's finding conflict with the pattern researcher's approach?)
- Coverage check (does every Done Criterion have at least one research finding supporting it?)

If GAPS → dispatch specific producers again. Max 1 round.

**Contradiction handling**: When findings conflict, write BOTH verbatim in `## Research Summary` as an Open Question. Do NOT silently pick one. The plan must address contradictions explicitly.

Collect all research + review outputs.

## Step 2.5: Size Re-evaluation

After research completes (skip for Size S with no research):

Count the actual affected files from research findings. Compare to sharp's size estimate:

| Sharp estimate | Actual files | Action |
|---|---|---|
| S | ≤ 3 files | Confirmed S |
| S | 4-10 files | **Upgrade to M** — update ## Size Re-evaluation, adjust approach |
| S | > 10 files | **Upgrade to L** — update ## Size Re-evaluation, run full research if not already done |
| M | ≤ 3 files | **Downgrade to S** — simplify plan accordingly |
| M | 4-15 files | Confirmed M |
| M | > 15 files | **Upgrade to L** — run remaining research domains if not covered |
| L | any | Confirmed L (already ran full research) |

Write `## Size Re-evaluation`:
```markdown
## Size Re-evaluation
Sharp estimate: {original}
Research evidence: {N} files affected, {reasoning}
Adjusted size: {confirmed | upgraded to M | downgraded to S}
Token budget: {updated if changed}
```

If size changed → update entity frontmatter `size:` field.

## Step 2.7: Scope Anchoring (M/L only)

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

## Step 3: Write Plan (TDD Task Structure)

Write a plan with concrete tasks. Each task must be completable by a single agent in one dispatch.

**TDD enforcement:** every task that produces application code must follow test-first order.

Format:

```markdown
## Plan

### Task 1: {name}
**Wave:** {0|1|2|...} — wave 0 for test infrastructure, same-wave tasks can run in parallel
**Files:** {create/modify with exact paths}
**Read first:** {files the agent must read before starting}
**Steps:**
1. Write the failing test:
   ```typescript
   // test code
   ```
2. Run test to verify it fails:
   `bun test {test-file} -- --grep "{test-name}"`
   Expected: FAIL with "{expected error}"
3. Write minimal implementation:
   ```typescript
   // implementation code
   ```
4. Run test to verify it passes:
   `bun test {test-file}`
   Expected: PASS
5. Run quality check: `bun build && tsc --noEmit`
**Done:** {runnable verification command}
**Model:** haiku | sonnet
```

### TDD Exceptions (non-code tasks)

Tasks that don't produce application code skip TDD:
- Config file changes (tsconfig, package.json)
- Pure refactor with existing test coverage
- Documentation-only tasks
- Migration/seed scripts (test via execution, not unit test)

Mark these as `**TDD:** skip — {reason}` in the task.

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

## Step 3.5: Verification Spec

Read `## Done Criteria` and `## Journey → DC Mapping` from sharp output. For each typed Done Criterion, fill in the exact verification procedure:

```markdown
## Verification Spec

| DC | Type | Assertion | Verify Procedure | Expected |
|----|------|-----------|-----------------|----------|
| DC-1 | ui | Detail page loads with comment panel | `curl -sf localhost:3000/entity/test \| grep 'comment-panel'` | matches |
| DC-2 | ui | Panel has input + submit | `curl -sf localhost:3000/entity/test \| grep 'comment-input'` | matches |
| DC-3 | api | POST returns 201 | `curl -s -o /dev/null -w "%{http_code}" -X POST localhost:3000/api/comments -d '{"text":"test"}'` | 201 |
| DC-4 | ui | Comment appears without refresh | `e2e-test flows/comment-sse.yaml` (if e2e available) or manual | steps pass |
| DC-5 | cli | Notification test passes | `bun test tests/notification.test.ts` | exit 0 |
```

**Verify Procedure rules by type:**

| Type | Procedure format | Fallback if infra unavailable |
|------|-----------------|------------------------------|
| `cli` | Exact bash command + expected exit code/output | — (always available) |
| `api` | `curl` command with method, URL, body, expected status + response pattern | — (always available) |
| `ui` | `curl` route + `grep` content (T2 level). If complex interaction → `e2e-test {flow.yaml}` | curl + grep (skip interaction check) |
| `skill` | `Skill("{skill-name}")` invoke + expected output shape | Note: can only verify in Claude Code session |
| `e2e` | `e2e-test {flow.yaml}` with step-by-step assertions | Degrade to `ui` type (curl + grep) |

**Every DC MUST have a Verify Procedure.** "Manual check" or "visually inspect" is a plan failure — find a programmatic way or degrade the type (e.g., `e2e` → `ui` with curl).

The Verification Spec table is consumed by:
- **Execute Step 5.1** — runs each procedure as first-pass
- **Verify Step 4** — runs each procedure independently as second-pass
- **Ship PR body** — includes procedure + results for reviewer reproduction

## Step 4: Self-Review (Plan-Checker Lite)

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

### Dimension 7 — TDD Compliance
Does every code-producing task follow test-first order (write test → verify fail → implement → verify pass)? Tasks with `TDD: skip` must have a valid reason.

### Dimension 8 — Stale-Line-Anchor Check
For every `file:line` citation in the plan (`read_first` entries, code snippets referencing specific lines, step instructions citing line numbers):

1. Read the cited file and line range
2. Does the content at that line match what the plan assumes?

| Result | Action |
|--------|--------|
| Content matches assumption | PASS — proceed silently |
| Line shifted but content exists nearby | WARNING — update the line number in the plan |
| Content contradicts assumption | BLOCKER — the plan is building on stale evidence. Fix the task or flag in Plan Review |
| File doesn't exist | BLOCKER — plan references a phantom path |

**This check is cheap (just Read calls) and catches the #1 cause of execute-stage BLOCKED returns** — plans written against a codebase state that changed between plan and execute.

**Fix issues inline.** Then re-review. Max 3 iterations.

## Step 4.5: Plan Review by Separate Agent

After self-review passes, dispatch a **review agent** to challenge the plan:

```
Agent(
  description: "Review plan: {entity-slug}",
  model: sonnet,
  prompt: |
    Review this implementation plan. You did NOT write it — challenge it.

    ## Problem
    {from entity}

    ## Done Criteria
    {from entity}

    ## Plan
    {full plan text}

    ## Challenge Checklist
    1. Can each task be completed by a SINGLE agent in ONE dispatch?
       (If a task requires reading the output of its own earlier steps → split it)
    2. Are the TDD test cases testing BEHAVIOR, not implementation?
       (Testing "function exists" is useless. Testing "input X → output Y" is useful.)
    3. Will a haiku-tier agent succeed at haiku-marked tasks?
       (If the task requires reading 3+ files to understand context → upgrade to sonnet)
    4. Are there missing tasks? (Read Done Criteria — is every criterion verifiable from the plan?)
    5. Is scope creep present? (Tasks that don't map to Done Criteria or Scope In → flag)

    Report:
    - APPROVED: plan is solid
    - REVISE: {list specific issues with fix suggestions}

    Be specific. "Task 3 could be better" is not actionable.
    "Task 3 should split — step 2 depends on step 1's output file" is actionable.
)
```

If REVISE → fix issues inline, re-run self-review (Step 4) once. Do NOT dispatch reviewer again — max 1 reviewer round.

If APPROVED → proceed to Step 5.

## Step 5: Write Entity Sections

```markdown
## Research Summary
{findings, or "Size S — no research needed"}
{Open Questions from contradictory research, if any}
{Reviewer assessment: APPROVED | GAPS addressed}

## Size Re-evaluation
Sharp estimate: {original}
Research evidence: {N files, reasoning}
Adjusted size: {confirmed | changed}

## Plan
{tasks with TDD structure and wave assignments}

## Plan Review
Iterations: {N} (self-review) + {1} (reviewer)
Status: {clean | gaps-noted}
Self-review dimensions: {8 dimensions, which passed/failed}
Reviewer verdict: {APPROVED | REVISE → fixed}
Scope anchoring: {all tasks mapped | gaps noted}
Estimated tasks: {count}
Estimated model split: {N haiku, M sonnet}
stage_cost: ${plan_cost} ({N} dispatches: {breakdown by model})
```

FO reads `stage_cost:` line and adds to entity frontmatter `token_actual` accumulation.

## Circuit Breakers

- Research producer timeout: 2 minutes per agent
- Research reviewer: max 1 gap-fill round
- Self-review loop: max 3 iterations → proceed with gaps noted
- Plan reviewer: max 1 round (no re-dispatch)
- Total plan stage: if > 20 minutes elapsed → write what you have and proceed
- Research contradictions: write both, never silently resolve
- Size re-evaluation: if upgraded, re-run missing research domains before planning

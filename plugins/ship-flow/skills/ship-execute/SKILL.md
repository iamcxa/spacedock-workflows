---
name: ship-execute
description: "Use when executing a plan's tasks via ensign dispatch. Agent-autonomous: wave-parallel dispatch with per-task model hints, implementer→reviewer two-stage loop, BLOCKED escalation ladder. No captain gate."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Execute — Wave-Parallel Dispatch and Build

You are running the EXECUTE stage of ship-flow. No captain interaction — dispatch agents wave-by-wave, verify each task, handle failures via escalation ladder.

## Entity Body Contract

**Reads:** `## Plan` (tasks, files, steps, model hints, waves), `## Size Assessment`, `## Project Skills`
**Writes (all mandatory):**
- `## Execution Log` — per-task table: agent, model, status, files changed, retries, review result, commit SHA
- `## Issues Found` — non-blocking findings → auto entity refs
**Optional writes:**
- `## Learnings` — insights discovered during execution (append-only)

---

## Step 1: Read Plan and Build Wave Graph

Read the entity file. Extract `## Plan` section — parse all tasks with their files, steps, verification commands, model hints, and **wave assignments**.

Build the wave graph:
- Group tasks by wave number (0, 1, 2, ...)
- Wave 0: test infrastructure (if declared)
- Same-wave tasks: can run in parallel (if no file overlap)
- Cross-wave: strictly sequential — wave N+1 starts only after wave N is fully committed

**Wave dependency sanity check**: For each task in wave N, verify that every path in its `read_first` list either (a) already exists in the worktree, or (b) is listed in `files_modified` of a task in wave < N.

If any violation found → write `## Execution Log` with `status: blocked, reason: wave dependency violation — {details}` and return. **Do NOT silently reorder waves.** The plan stage owns wave topology.

**Input validation**: If `## Plan` is missing or malformed → write `## Execution Log` with `status: blocked` and return. Do NOT execute on partial input.

---

## Step 2: Execute Tasks (Wave-by-Wave)

Iterate waves sequentially. Inside each wave, dispatch implementation subagents:

### Dispatch Pattern

For each task in the current wave:

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
    1. Read the files listed in "Read first" before starting
    2. Implement exactly what the task specifies
    3. Write tests if the task says to
    4. Run the verification command from "Done"
    5. Report status with changed files list

    ## Status Protocol (mandatory — report exactly one)

    **DONE**: Task completed, verification passed. Return:
    - changed_files: [list of files modified]
    - verification_output: {command output}

    **NEEDS_CONTEXT**: Cannot proceed — need specific information. Return:
    - missing: {what you need — be specific}
    - attempted: {what you tried}

    **BLOCKED**: Cannot complete — plan issue or external dependency. Return:
    - blocked_reason: {why — be specific}
    - attempted: {what you tried}

    ## Quality Check — Tiered (mandatory before reporting DONE)

    ### Tier 1 (always, ~30s):
    Run ALL of these. ALL must pass:
    ```bash
    bun build 2>&1
    tsc --noEmit 2>&1
    bun test 2>&1
    ```
    If any fail → fix and retry (max 3 attempts).

    ### Tier 2 (only if your task touched frontend files — ui/, app/, components/, pages/, *.tsx):
    ```bash
    timeout 30 bun dev &
    sleep 5
    curl -sf http://localhost:3000 > /dev/null && echo "T2: root OK" || echo "T2: root FAIL"
    curl -sf http://localhost:3000/{affected-route} > /dev/null && echo "T2: route OK" || echo "T2: route FAIL"
    kill %1 2>/dev/null
    ```
    If T2 fails → fix before reporting DONE. T2 failures count toward retries.

    Do NOT commit — return changed_files and status. Orchestrator handles commits.

    Work from: {project_root}
)
```

### Parallelism Within Waves

- Tasks in the same wave with **no `files_modified` overlap** → dispatch in parallel (multiple Agent calls in one tool-call block)
- Tasks with file overlap or `serial: true` → dispatch sequentially within the wave
- Never start wave N+1 while any task in wave N is still in flight

---

## Step 3: Handle Task Returns

For each task return, process by status:

### DONE
1. Schedule for commit in Step 3.5
2. Dispatch immediate review (see Step 4)

### NEEDS_CONTEXT
1. Gather the missing information from the entity body, plan, or worktree
2. Re-dispatch the same task (same model) with extra context prepended
3. **Cap: 2 NEEDS_CONTEXT rounds per task.** Third round → reclassify as BLOCKED

### BLOCKED — Escalation Ladder

BLOCKED means "cannot complete as judged by this model tier." Escalate model tiers before declaring terminal failure:

1. **First BLOCKED (on haiku)** → re-dispatch as **sonnet** with the `blocked_reason` in prompt
2. **Second BLOCKED (on sonnet)** → re-dispatch as **opus** with accumulated blocked_reasons
3. **Third BLOCKED (on opus)** → **terminal failure**. Log to `## Execution Log`, create auto-issue entity

**This is NOT a retry loop** — each tier is a fundamentally different reasoning budget. haiku→sonnet→opus is three different strategies, not three retries of one.

**Never skip a tier.** Never retry the same tier twice. Never jump straight to "replan" on first BLOCKED.

### Benign-Drift Pre-Check

Before the escalation ladder fires on a BLOCKED return, check for benign drift using substring matching:

1. **anchor-drift** — `blocked_reason` contains `line` AND one of: `mismatch`, `shifted`, `not found at line`, `content moved` → auto-proceed as DONE + log `scope_observation`
2. **file-renamed** — `blocked_reason` contains `read_first` AND one of: `not found`, `ENOENT`, `does not exist`. Verify via `git log --diff-filter=R --follow -- <path>`. Rename confirmed → auto-proceed. No rename → fall through to ladder.
3. **semantic-grep-mismatch** — `blocked_reason` contains `grep` AND `count`, and the searched string appears in the plan text itself (circular reference) → auto-proceed + log `scope_observation`

Match → classify as DONE + inject `scope_observation` finding. No match → proceed to escalation ladder.

---

## Step 3.5: Serial Commits After Each Wave

Once every task in the wave has reached terminal state, commit DONE tasks serially:

```bash
# One commit per task, in wave order — never batched
git add {task.files_modified}
git commit -m "feat(execute): {slug} task-{N} — {one-line action summary}"
```

**One commit per task.** A wave of 3 DONE tasks = 3 commits, not 1. This preserves `git bisect` and PR review decomposition.

**Pre-commit hook fires per commit.** Do NOT override with `--no-verify`. If the hook fails → revert staged edits, reclassify the task as BLOCKED, follow escalation ladder.

After last commit in wave, capture HEAD as baseline for next wave.

---

## Step 4: Review Each Task (Immediate — Do NOT Batch)

**Every task gets reviewed immediately after DONE.** The loop is: implement → review → fix → re-review → next task.

Dispatch a review subagent right after each implementation agent reports DONE:

```
Agent(
  description: "Review Task {N}: {name}",
  model: haiku,  // Reviews are mechanical — haiku is sufficient
  prompt: |
    Review the changes from Task {N}: {name}.

    ## What was requested
    {task text from plan}

    ## What changed
    Run: git diff HEAD~1 --stat && git diff HEAD~1
    
    ## Check (all 5 mandatory)
    1. Does the diff match what the task requested? (no more, no less)
    2. Are there obvious bugs, missing error handling, or broken imports?
    3. Do tests exist for new functionality?
    4. Did the implementation agent report T1 quality check PASS?
    5. If frontend change: did T2 smoke check PASS?
    
    ## Non-blocking findings
    Issues that don't affect THIS task's correctness
    (tech debt, style improvements, refactor opportunities):
    - List under "## Non-Blocking" — do NOT mark as NEEDS_FIX
    
    Report: APPROVED | NEEDS_FIX (list specific BLOCKING issues only)
)
```

**Review loop:**
- NEEDS_FIX → dispatch fix agent (same model as original task) with specific issues
- Fix agent commits → re-dispatch review agent
- Max 3 rounds per task
- Round 3 still NEEDS_FIX → log as failed, create auto-issue entity

**Non-blocking findings → auto entity:**
If review reports non-blocking findings, create a new draft entity:
```
Entity: {slug}-improve-{task-N}
Status: draft
Source: "auto:ship-flow review"
```

---

## Step 5: Wave Completion and Frontend Smoke

After all waves complete, check if frontend files were touched:

```bash
git diff {execute_start_sha}..HEAD --name-only | grep -E '^(ui/|app/|components/|pages/|src/.*\.tsx)'
```

If yes → run Tier 2 smoke check:
```bash
timeout 30 bun dev &
sleep 5
curl -sf http://localhost:3000 > /dev/null && echo "T2: root OK" || echo "T2: root FAIL"
kill %1 2>/dev/null
```

Log result to `## Execution Log`.

---

## Step 6: Write Entity Sections

```markdown
## Execution Log

| Task | Wave | Model | Status | Files Changed | Retries | Review | Commit |
|------|------|-------|--------|---------------|---------|--------|--------|
| 1: {name} | 1 | haiku | done | file1.ts, file2.ts | 0 | approved | abc1234 |
| 2: {name} | 1 | sonnet | done | file3.ts | 1 | approved (round 2) | def5678 |
| 3: {name} | 2 | haiku | blocked→sonnet done | file4.ts | 0+1 | approved | ghi9012 |

### Escalations
- Task 3: haiku BLOCKED ("type error in dependency") → sonnet DONE

### Frontend smoke
{PASS/FAIL/N/A}

### Scope observations
{benign-drift auto-proceeds, if any}

## Issues Found
- {non-blocking findings} → auto-created entity #{slug}-improve-N
```

---

## Circuit Breakers

- Per-task implementation retry: max 3 attempts
- Per-task review loop: max 3 rounds
- BLOCKED escalation: haiku → sonnet → opus (once each, never same tier twice)
- NEEDS_CONTEXT rounds: max 2, then reclassify as BLOCKED
- Total blocked tasks: > 50% of tasks blocked → escalate to captain
- Wave integrity: dependency violation → return to plan, never silent reorder
- Token tracking: log each agent dispatch cost to entity frontmatter `token_actual`

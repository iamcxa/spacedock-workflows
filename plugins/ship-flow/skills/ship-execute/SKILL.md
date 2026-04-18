---
name: ship-execute
description: "Use when executing a plan's tasks via ensign dispatch. Agent-autonomous: wave-parallel dispatch with per-task model hints, implementer→reviewer two-stage loop, BLOCKED escalation ladder. No captain gate."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Execute — Wave-Parallel Dispatch and Build

You are running the EXECUTE stage of ship-flow. No captain interaction — dispatch agents wave-by-wave, verify each task, handle failures via escalation ladder.

## Entity Body Contract

**Schema:** `references/entity-body-schema.yaml` → `stages.execute`

**Reads:** `## Plan Output` (all subsections), `## Sharp Output` → Done Criteria
**Writes:**
- `## Execute Output` — subsections: Execution Log (per-task table), Issues Found, Knowledge Captures (D1/D2)
- `## Execute Report` — status, stage_cost, tasks summary, knowledge capture
- `## Execute UAT` — first-pass AC verification (not authoritative — verify re-runs independently)

---

## Step 1: Read Plan and Build Wave Graph

Record the current time as the stage start timestamp (ISO 8601 format).

Read the entity file. Extract `## Plan Output → ### Plan` section — parse all tasks with their files, steps, verification commands, model hints, and **wave assignments**.

Build the wave graph:
- Group tasks by wave number (0, 1, 2, ...)
- Wave 0: test infrastructure (if declared)
- Same-wave tasks: can run in parallel (if no file overlap)
- Cross-wave: strictly sequential — wave N+1 starts only after wave N is fully committed

**Wave dependency sanity check**: For each task in wave N, verify that every path in its `read_first` list either (a) already exists in the worktree, or (b) is listed in `files_modified` of a task in wave < N.

If any violation found → write `### Execution Log` (under `## Execute Output`) with `status: blocked, reason: wave dependency violation — {details}` and return. **Do NOT silently reorder waves.** The plan stage owns wave topology.

**Input validation**: If `## Plan Output → ### Plan` is missing or malformed → write `### Execution Log` (under `## Execute Output`) with `status: blocked` and return. Do NOT execute on partial input.

---

## Self-Drive Rule (Anti-Idle)

**Do not idle between tasks.** After completing one task (DONE, commit, review), immediately proceed to the next task in the current wave or advance to the next wave. Do not wait for external input between tasks. The entire execute stage is a single continuous run — you have all the context you need from the Plan section.

If you find yourself at a turn boundary with remaining tasks, your next action must be dispatching or implementing the next task. Pausing between tasks wastes time and risks session-level idle timeout.

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

    **DONE_WITH_CONCERNS**: Task completed and verification passed, but you have doubts. Return:
    - changed_files: [list of files modified]
    - verification_output: {command output}
    - concerns: {what worries you — correctness doubt, edge case, scope question}

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

### DONE_WITH_CONCERNS
1. Read the concerns before proceeding
2. If concerns are about **correctness or scope** (e.g., "not sure this handles the edge case", "might conflict with X") → address the concern before review. Options: re-dispatch with clarification, or note the concern for reviewer to check specifically.
3. If concerns are **observations** (e.g., "this file is getting large", "naming could be better") → note in `### Issues Found` and proceed to commit + review as normal DONE.
4. Log concerns in `### Execution Log` under the task's row as `concerns: {text}`.

### NEEDS_CONTEXT
1. Gather the missing information from the entity body, plan, or worktree
2. Re-dispatch the same task (same model) with extra context prepended
3. **Cap: 2 NEEDS_CONTEXT rounds per task.** Third round → reclassify as BLOCKED

### BLOCKED — Escalation Ladder

BLOCKED means "cannot complete as judged by this model tier." Escalate model tiers before declaring terminal failure:

1. **First BLOCKED (on haiku)** → re-dispatch as **sonnet** with the `blocked_reason` in prompt
2. **Second BLOCKED (on sonnet)** → re-dispatch as **opus** with accumulated blocked_reasons
3. **Third BLOCKED (on opus)** → **terminal failure**. Log to `### Execution Log`, create auto-issue entity

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
    Issues that don't affect this task's correctness
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

## Step 5: Wave Completion, AC Verification, and Frontend Smoke

After all waves complete:

### 5.1: AC Verification (First-Pass)

Read `## Plan Output → ### Verification Spec`. For each row, run the Verify Procedure by type:

| Type | How to run |
|------|-----------|
| `cli` | Bash: run command, check exit code + output |
| `api` | Bash: run curl command, check status + response |
| `ui` | Bash: curl route + grep content. If e2e flow exists → `Skill("e2e-pipeline:e2e-test")` |
| `skill` | `Skill("{skill-name}")` with probe prompt, check output shape |
| `e2e` | `Skill("e2e-pipeline:e2e-test")` if available, otherwise degrade to `ui` type + warn |

Record each result in the AC Verification table (see Step 6 output). This is the execute-stage first-pass — verify stage re-runs independently as a second opinion.

If any criterion fails → log the failure but do NOT block. Verify stage is the authoritative gate.

### 5.2: Frontend Smoke

Check if frontend files were touched:

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

Log result to `### Execution Log`.

---

## Step 6: Write Entity Sections

```markdown
## Execute Output

### Execution Log

| Task | Wave | Model | Status | Files Changed | Retries | Review | Commit | Est. Cost |
|------|------|-------|--------|---------------|---------|--------|--------|-----------|
| 1: {name} | 1 | haiku | done | file1.ts, file2.ts | 0 | approved | abc1234 | ~$0.10 |
| 2: {name} | 1 | sonnet | done | file3.ts | 1 | approved (round 2) | def5678 | ~$1.50 |
| 3: {name} | 2 | haiku | blocked→sonnet done | file4.ts | 0+1 | approved | ghi9012 | ~$0.55 |

Escalations:
- Task 3: haiku BLOCKED ("type error in dependency") → sonnet DONE

Frontend smoke: {PASS/FAIL/N/A}

Scope observations: {benign-drift auto-proceeds, if any}

### Issues Found
- {non-blocking findings} → auto-created entity #{slug}-improve-N

### Knowledge Captures
{see Step 5.3}

## Execute UAT

| Done Criterion | Verify Command | Result |
|----------------|---------------|--------|
| POST /api/comments returns 201 | `curl -s -o /dev/null -w "%{http_code}" -X POST localhost:3000/api/comments` | 201 PASS |
| bun test passes with new test | `bun test` | 143 pass, 0 fail PASS |

## Execute Report
status: {passed | failed | blocked}
stage_cost: ${execute_cost} ({N} dispatches: {breakdown by model})
Tasks: {N done, M blocked, K needs-context-rounds}
Knowledge capture: {D1: N, D2: M | skipped}
started_at: "{ISO 8601 timestamp}"
completed_at: "{ISO 8601 timestamp}"
duration_minutes: {number}
```

---

## Step 5.3: Knowledge Capture (Conditional)

After AC verification, scan all findings surfaced during execution (scope_observations, review non-blocking findings, DONE_WITH_CONCERNS concerns, escalation patterns). Classify each finding that **generalizes beyond this entity**:

**D1 — Skill-Level Pattern** (auto-write, no captain gate):
Patterns that future agents should know. Tag `[D1]` in `### Knowledge Captures`. Examples:
- "This codebase uses `createSnapshot()` synchronously — async wrappers must preserve sync return"
- "`bun test` needs `--preload ./setup.ts` for integration tests"

**D2 — Project-Level Candidate** (staged for captain):
Architectural decisions or constraints worth adding to CLAUDE.md. Tag `[D2-candidate]` in `### Knowledge Captures`. Examples:
- "Dashboard must remain SSR-compatible — no `window` access in shared modules"
- "All API routes require auth middleware — no public endpoints"

Ship-review stage surfaces `[D2-candidate]` items to captain during finalization.

**Skip when**: All findings are entity-specific. Log: `Knowledge capture: skipped — no findings met D1/D2 threshold`

---

## Token Tracking

### Per-Stage Cost Estimation

Agent dispatch cost is estimated (not metered — Claude Code Agent tool does not return usage metadata). Use dispatch-count heuristics per model tier:

| Model | Estimated cost per dispatch |
|-------|---------------------------|
| opus | ~$2.00 (heavy reasoning, large context) |
| sonnet | ~$0.50 (standard tasks) |
| haiku | ~$0.05 (mechanical review, classification) |

These are order-of-magnitude estimates based on typical agent context sizes (~50K input + ~5K output tokens). Actual costs vary by task complexity.

### Accumulation

After each Agent dispatch (implementation, review, or escalation), add the model's estimated cost to a running total:

```
execute_cost = sum of all dispatches in this stage
```

Write in `## Execute Report`:

```
status: {passed | failed | blocked}
stage_cost: ${execute_cost} ({N} dispatches: {breakdown by model})
```

FO reads `status:` and `stage_cost:` lines for dispatch decisions and `token_actual` accumulation. Calculate duration from the recorded start timestamp to now. Write started_at, completed_at, and duration_minutes to the report.

### Budget Check

After each dispatch, compute running total. If `execute_cost + prior_stages_cost > token_budget × 2` → pause execution, log warning in `### Execution Log`, notify captain. Do NOT silently continue.

### Cost Column in Execution Log

```
| Task | Model | Status | Files | Retries | Review | Est. Cost |
|------|-------|--------|-------|---------|--------|-----------|
| 1    | haiku | done   | ...   | 0       | approved | ~$0.10 |
| 2    | sonnet | done  | ...   | 1       | approved | ~$1.50 |
```

## Circuit Breakers

- Per-task implementation retry: max 3 attempts
- Per-task review loop: max 3 rounds
- BLOCKED escalation: haiku → sonnet → opus (once each, never same tier twice)
- NEEDS_CONTEXT rounds: max 2, then reclassify as BLOCKED
- Total blocked tasks: > 50% of tasks blocked → escalate to captain
- Wave integrity: dependency violation → return to plan, never silent reorder
- Token overrun: token_actual > token_budget × 2 → pause, ask captain
- Token tracking: log each agent dispatch cost to entity frontmatter `token_actual`

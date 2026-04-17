---
name: ship-review
description: "Use when all execute tasks are complete and the entity is ready for final verification + PR. Agent-autonomous: tiered UAT, final review, PR creation."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Review — Verify and Ship

You are running the SHIP stage of ship-flow. No captain interaction — verify the work, create the PR, notify captain. After this stage, FO advances to `done` (terminal) which triggers the merge hook.

## Entity Body Contract

**Reads:** `## Done Criteria`, `## Execution Log`, `## Issues Found`, `## Size Assessment`
**Writes (all mandatory):**
- `## UAT Results` — tiered verification results (T1/T2/T3) + done criteria checklist
- `## Ship Report` — verdict, PR link, token actual, task summary
**Optional writes:**
- `## Learnings` — insights discovered during review (append-only)

## Step 1: Read Execution Results

Read the entity file. Extract:
- `## Done Criteria` — what must be true
- `## Execution Log` — what was done
- `## Issues Found` — any auto-created entities

Check: if > 50% of tasks failed in execute → do NOT proceed. Set verdict to `blocked`, notify captain.

## Step 2: UAT Verification (Tiered)

### Tier 1 — Always (all changes)

```bash
bun build 2>&1
tsc --noEmit 2>&1
bun test 2>&1
```

All must pass. If any fail → feedback to execute (max 2 rounds, then escalate to captain).

### Tier 2 — Frontend Changes

Check if frontend files were touched:
```bash
git diff {execute_base}..HEAD --name-only | grep -E '^(ui/|app/|components/|pages/|src/.*\.tsx)'
```

If yes:
```bash
timeout 30 bun dev &
sleep 5
# Check key routes return 200
for route in "/" "/entity" "/api/events"; do
  STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:3000${route}" 2>/dev/null)
  echo "Route ${route}: ${STATUS}"
done
kill %1 2>/dev/null
```

Any non-200 → feedback to execute.

### Tier 3 — E2E (Phase 2, not MVP)
Reserved for future e2e-pipeline integration. Skip for now.

## Step 3: Done Criteria Check

For each criterion in `## Done Criteria`:
- Run the verification (command, check, or inspection)
- Mark pass/fail

```markdown
## UAT Results

### Tier 1
- build: PASS
- typecheck: PASS  
- tests: PASS (142 pass, 0 fail)

### Tier 2
- Route /: 200 PASS
- Route /entity: 200 PASS
- Route /api/events: 200 PASS

### Done Criteria
- [x] POST /api/comments returns 201 with comment ID
- [x] Claude receives notification within 5s
- [x] bun test passes with new test
```

If any Done Criterion fails → feedback to execute with specific failure.

## Step 4: Final Review

Dispatch one review subagent for the complete diff:

```
Agent(
  description: "Final review: {entity-slug}",
  model: sonnet,
  prompt: |
    Review the complete changes for entity: {title}

    ## Problem
    {from entity}

    ## Done Criteria
    {from entity}

    ## Full diff
    Run: git diff {execute_base}..HEAD

    ## Check
    1. Do changes solve the stated problem?
    2. Are there security issues? (hardcoded secrets, SQL injection, XSS)
    3. Is there dead code or debug artifacts left behind?
    4. Are error cases handled?
    
    Report:
    - SHIP IT — ready to merge
    - NEEDS_FIX — list specific blocking issues (not style nits)
    
    Only block for real problems. Style preferences are not blocking.
)
```

If NEEDS_FIX → dispatch fix agent → re-review. Max 2 rounds, then escalate to captain.

## Step 5: Create PR

```bash
# Ensure we're on a feature branch (should be from worktree)
BRANCH=$(git branch --show-current)
git push origin "${BRANCH}"

# Create PR
gh pr create \
  --title "{entity title}" \
  --body "## Problem
{from entity}

## Done Criteria
{from entity, with checkmarks}

## Changes
{from execution log — task summary}

Entity: #{entity-id}
Ship-flow: sharp → plan → execute → ship (autonomous)" \
  --base main
```

## Step 6: Write Entity Sections + Finalize

```markdown
## UAT Results
{from Step 3}

## Ship Report
Verdict: shipped
PR: {pr-url}
Token actual: {cumulative from all stages}
Tasks: {done}/{total} ({failed} failed, {issues} auto-issues created)
```

Update entity frontmatter:
```yaml
status: ship
pr: "{pr-number}"
token_actual: {total}
```

Note: Do NOT set `status: done` or `completed:` or `verdict:` — the FO advances to `done` (terminal) after this stage completes, which triggers the merge hook. The merge hook handles the final frontmatter updates.

Update ROADMAP.md: move entity from "In-Flight" to "Shipped".

Notify captain:

> **Shipped: {title}**
> PR: {pr-url}
> Done criteria: {all pass}
> Cost: ${token_actual}
> Issues found: {count, with entity refs}

## Circuit Breakers

- UAT fail → execute feedback: max 2 rounds
- Final review → fix: max 2 rounds
- After all max retries exhausted → escalate to captain
- Token overrun: if token_actual > token_budget × 2 → pause, notify captain

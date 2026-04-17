---
name: ship-review
description: "Use when all execute tasks are complete and the entity is ready for final verification + PR. Agent-autonomous: 5-check quality gate, themed review dispatch, done criteria UAT, PR creation."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Review — Quality Gate, Review, and Ship

You are running the REVIEW stage of ship-flow. No captain interaction — run full-project quality checks, dispatch themed reviewers, verify done criteria, create the PR. After this stage, FO advances to `done` (terminal) which triggers the merge hook.

This stage combines three concerns that were separate in the build pipeline:
- **Quality** (build-quality) — mechanical full-project verification
- **Review** (build-review) — judgment-bearing code review with themed reviewers
- **UAT** (build-uat) — done criteria verification against captain's acceptance

## Entity Body Contract

**Reads:** `## Done Criteria`, `## Execution Log`, `## Issues Found`, `## Size Assessment`, `## Plan`
**Writes (all mandatory):**
- `## Quality Gate` — 5-check results (test/lint/typecheck/build/format)
- `## Review Findings` — classified findings from themed reviewers
- `## UAT Results` — done criteria checklist with verification evidence
- `## Ship Report` — verdict, PR link, token actual, task summary
**Optional writes:**
- `## Learnings` — insights discovered during review (append-only)

---

## Step 1: Read Execution Results

Read the entity file. Extract:
- `## Done Criteria` — what must be true
- `## Execution Log` — what was done, commit SHAs
- `## Issues Found` — any auto-created entities
- `## Size Assessment` — determines review depth
- `## Plan` — for `files_modified` cross-check

**Pre-check**: if > 50% of tasks failed in execute → do NOT proceed. Set verdict to `blocked`, notify captain.

Capture execute base SHA from `## Execution Log` (first task's parent commit).

---

## Step 2: Quality Gate — 5-Check Full-Project Verification

Run ALL 5 checks against the full project. **No scope narrowing** — even if execute only touched one file, quality checks the entire project. Binary pass/fail per check, no judgment.

### Check 1: Tests
```bash
bun test 2>&1
```
Verdict: exit code 0 and no failing tests → PASS. Otherwise → FAIL.

### Check 2: Lint
```bash
bun lint 2>&1
```
Verdict: exit code 0 → PASS. Warnings-only → PASS. Errors → FAIL.

### Check 3: Type Check
```bash
bunx tsc --noEmit 2>&1
```
Verdict: exit code 0 and no `error TS` lines → PASS. Otherwise → FAIL.

### Check 4: Build
```bash
bun build 2>&1
```
Verdict: exit code 0 → PASS. Otherwise → FAIL.

### Check 5: Format (if formatter configured)
```bash
bunx prettier --check "src/**/*.{ts,tsx}" 2>&1 || echo "no formatter configured"
```
Verdict: exit code 0 or no formatter → PASS. Otherwise → FAIL (advisory, not blocking).

**Capture last 40 lines of each check's output as evidence.**

**Any of checks 1-4 FAIL → feedback to execute.** Do NOT proceed to review. Max 2 feedback rounds, then escalate to captain.

```markdown
## Quality Gate
- tests: PASS (142 pass, 0 fail)
- lint: PASS
- typecheck: PASS
- build: PASS
- format: PASS (advisory)
```

---

## Step 3: Themed Review Dispatch (Size-Adaptive)

Compute review scope:
```bash
git diff {execute_base}..HEAD --stat
```

### Size S (< 5 changed files) — Lite Review

Dispatch one review subagent:

```
Agent(
  description: "Review: {entity-slug}",
  model: sonnet,
  prompt: |
    Review git diff {execute_base}..HEAD for entity: {title}

    ## Problem: {from entity}
    ## Done Criteria: {from entity}

    Check:
    1. Do changes solve the stated problem? (no more, no less)
    2. Security: hardcoded secrets, injection, XSS?
    3. Dead code or debug artifacts left behind?
    4. Error cases handled?
    5. Stale references to removed symbols?

    Report: SHIP IT | NEEDS_FIX (list specific blocking issues only)
    Style preferences are NOT blocking.
)
```

### Size M (5-15 files) — Standard Review

Dispatch 2 themed reviewers in parallel:

```
Agent 1 — Correctness:
  Focus: bugs, error handling, logic errors, silent failures, regressions
  Check: diff matches plan, no unhandled errors, tests cover new paths

Agent 2 — Style + Types:
  Focus: clarity, type design, complexity, test coverage gaps
  Check: types are well-designed, no unnecessary complexity, tests exist
```

### Size L (> 15 files) — Full Review

Dispatch 3 themed reviewers in parallel:

```
Agent 1 — Security:
  Focus: unsafe defaults, injection, hardcoded secrets, attack surface
  
Agent 2 — Correctness:
  Focus: bugs, error handling, logic errors, silent failures

Agent 3 — Style + Types:
  Focus: clarity, type design, complexity, test coverage
```

### Pre-Scan (All Sizes, Inline Before Dispatch)

Before dispatching reviewers, run these mechanical checks inline:

1. **Stale references**: For every symbol removed by the diff, grep for remaining references. Hit outside the diff = stale reference finding.
2. **Plan consistency**: Cross-check `git diff --stat` file list against `## Plan` `files_modified`. Files changed but not in plan = unplanned change finding. Files in plan but unchanged = missed task finding.

### Finding Classification

For each finding from reviewers, classify:

| Severity | Routing |
|----------|---------|
| **BLOCKING** — security hole, broken functionality, data loss risk | NEEDS_FIX → dispatch fix agent |
| **WARNING** — potential bug, missing edge case, weak error handling | Log, proceed if no BLOCKING |
| **NIT** — style, naming, minor improvement | Log as non-blocking, auto-create draft entity if warranted |

**Review loop:**
- NEEDS_FIX → dispatch fix agent (sonnet) with specific issues
- Fix agent commits → re-dispatch review
- Max 2 rounds
- Round 2 still NEEDS_FIX → escalate to captain

```markdown
## Review Findings
Scope: {N} files, {M} reviewers dispatched

### Pre-scan
- Stale references: {none | list}
- Plan consistency: {all files match | discrepancies}

### Reviewer findings
| Severity | File:Line | Description | Reviewer |
|----------|-----------|-------------|----------|
| BLOCKING | src/api.ts:42 | Silent swallow of 4xx | correctness |
| WARNING | src/types.ts:10 | Stale comment | style |

Verdict: {SHIP IT | NEEDS_FIX round N | escalated}
```

---

## Step 4: Done Criteria UAT

For each criterion in `## Done Criteria`:
- Run the verification command or check
- Record pass/fail with evidence
- Classify failures:
  - **Infra-fail** — command not found, server not running, binary missing → feedback to execute
  - **Assertion-fail** — command ran but output doesn't match → specific failure logged

```markdown
## UAT Results

### Quality Gate
{from Step 2}

### Done Criteria
- [x] POST /api/comments returns 201 with comment ID — `curl -s localhost:3000/api/comments -X POST | jq .id` → "abc123"
- [x] Claude receives notification within 5s — verified via test
- [x] bun test passes with new test — 143 pass, 0 fail

### Frontend Smoke (if applicable)
- Route /: 200 PASS
- Route /entity: 200 PASS
```

If any Done Criterion fails → feedback to execute with specific failure. Max 2 rounds.

---

## Step 5: Create PR

```bash
BRANCH=$(git branch --show-current)
git push origin "${BRANCH}"

gh pr create \
  --title "{entity title}" \
  --body "## Problem
{from entity}

## Done Criteria
{from entity, with checkmarks}

## Changes
{from execution log — task summary}

## Quality
{5-check results}

Entity: #{entity-id}
Ship-flow: sharp → plan → execute → review (autonomous)" \
  --base main
```

---

## Step 6: Write Entity Sections + Finalize

```markdown
## Ship Report
Verdict: shipped
PR: {pr-url}
Token actual: {cumulative from all stages}
Tasks: {done}/{total} ({failed} failed, {issues} auto-issues created)
Quality: {5/5 pass}
Review: {verdict from Step 3}
UAT: {all done criteria pass}
```

Update entity frontmatter:
```yaml
status: ship
pr: "{pr-number}"
token_actual: {total}
```

Note: Do NOT set `status: done` or `completed:` or `verdict:` — the FO advances to `done` (terminal) after this stage completes, which triggers the merge hook.

Update ROADMAP.md: move entity from "In-Flight" to "Shipped".

Notify captain:

> **Shipped: {title}**
> PR: {pr-url}
> Done criteria: {all pass}
> Quality: {5/5 checks pass}
> Review: {N findings, M blocking → resolved}
> Cost: ${token_actual}
> Issues found: {count, with entity refs}

---

## Circuit Breakers

- Quality gate fail → execute feedback: max 2 rounds
- Review NEEDS_FIX → fix + re-review: max 2 rounds
- Done criteria fail → execute feedback: max 2 rounds
- After all max retries exhausted → escalate to captain
- Token overrun: if token_actual > token_budget × 2 → pause, notify captain
- Infra-fail vs assertion-fail: infra routes to execute automatically, assertion requires specific evidence

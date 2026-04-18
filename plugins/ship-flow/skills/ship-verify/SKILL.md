---
name: ship-verify
description: "Use when execute tasks are complete and the entity needs verification before shipping. Agent-autonomous gate: 5-check quality, themed review classification, done criteria UAT. Feedback-to execute on failure."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Verify — Quality Gate, Review, and UAT

You are running the VERIFY stage of ship-flow. No captain interaction — run full-project quality checks, review the diff, verify done criteria. This stage is a gate: PASS advances to ship, FAIL feeds back to execute.

**You are NOT the author of this code.** You are a fresh agent reviewing work done by a different execute-stage ensign. Review the diff as an independent reviewer — do not assume correctness.

This stage combines three verification concerns:
- **Quality** — mechanical full-project verification (5 checks)
- **Review** — judgment-bearing code review classification (debate-driven)
- **UAT** — done criteria verification against captain's acceptance

## Entity Body Contract

**Reads:** `## Done Criteria`, `## Execution Log`, `## Issues Found`, `## Size Assessment`, `## Plan`, `PRODUCT.md` (constraints check)
**Writes (all mandatory):**
- `## Quality Gate` — 5-check results (test/lint/typecheck/build/format)
- `## Review Findings` — classified findings from themed reviewers
- `## UAT Results` — done criteria checklist with verification evidence
- `## Verify Report` — verdict (PASS/FAIL), blocking issues, feedback routing
**Optional writes:**
- `## Learnings` — insights discovered during verification (append-only)

---

## Step 1: Read Execution Results

Read the entity file. Extract:
- `## Done Criteria` — what must be true
- `## Execution Log` — what was done, commit SHAs
- `## Issues Found` — any auto-created entities
- `## Size Assessment` — determines review depth
- `## Plan` — for `files_modified` cross-check
- `PRODUCT.md` — constraints to verify against (if exists)

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

## Step 3: Themed Review — Read and Classify

The verify stage uses `dispatch: debate-driven`. This means:
- **FO handles reviewer dispatch** — FO creates themed reviewer teammates, they debate via SendMessage, then FO dispatches YOU (the ensign) to classify their findings.
- **You do NOT dispatch reviewers yourself.** You read the findings that are already in the entity file from the debate phase.

**Size S exception:** For S-size entities (< 5 changed files), FO may skip debate dispatch and fall back to bare mode. This is by design — a 2-file fix doesn't warrant 3 themed reviewers debating. When debate is skipped, you run an inline review yourself (see "Read Reviewer Findings" below). Note this in `## Review Findings` as `"Size S — bare mode inline review (no debate dispatched)."`

### Pre-Scan (Inline — Before Reading Reviewer Findings)

Run these mechanical checks yourself:

1. **Stale references**: For every symbol removed by the diff, grep for remaining references. Hit outside the diff = stale reference finding.
2. **Plan consistency**: Cross-check `git diff --stat` file list against `## Plan` `files_modified`. Files changed but not in plan = unplanned change finding. Files in plan but unchanged = missed task finding.
3. **Constraint check**: If `PRODUCT.md` has `## Constraints`, verify changes don't violate any (e.g., "channel-only" constraint → no standalone mode code added).

### Read Reviewer Findings

Read `## Review Debate` from the entity file (written by FO from debate output). Parse each finding.

If `## Review Debate` is missing (FO fell back to bare mode, or Size S with no debate):
- Run a single inline review yourself using the diff:
  ```bash
  git diff {execute_base}..HEAD
  ```
  Check: (1) changes match plan, (2) security, (3) dead code, (4) error handling, (5) stale refs.

### Finding Classification

For each finding (from debate or inline review), classify:

| Severity | Routing |
|----------|---------|
| **BLOCKING** — security hole, broken functionality, data loss risk | NEEDS_FIX → request FO dispatch fix agent |
| **WARNING** — potential bug, missing edge case, weak error handling | Log, proceed if no BLOCKING |
| **NIT** — style, naming, minor improvement | Log as non-blocking, auto-create draft entity if warranted |

**If BLOCKING findings exist:**
- Write classification to `## Review Findings`
- Report NEEDS_FIX to FO with specific blocking issues
- FO dispatches fix agent → debate reviewers re-review → you re-classify
- Max 2 rounds, then escalate to captain

```markdown
## Review Findings
Scope: {N} files, {M} reviewers dispatched (or "inline review — bare mode")

### Pre-scan
- Stale references: {none | list}
- Plan consistency: {all files match | discrepancies}
- Constraint check: {all constraints respected | violations}

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

## Step 5: Write Verify Report

```markdown
## Verify Report
Verdict: {PASS | FAIL}
Quality: {5/5 pass}
Review: {verdict from Step 3}
UAT: {all done criteria pass | N failed}
Blocking issues: {none | list}
```

If verdict PASS → FO advances to ship.
If verdict FAIL → FO routes feedback-to execute with Verify Report as context.

## Circuit Breakers

- Quality gate fail → execute feedback: max 2 rounds
- Review NEEDS_FIX → fix + re-review: max 2 rounds
- Done criteria fail → execute feedback: max 2 rounds
- After all max retries exhausted → escalate to captain
- Infra-fail vs assertion-fail: infra routes to execute automatically, assertion requires specific evidence

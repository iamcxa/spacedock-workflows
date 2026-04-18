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

## Step 3: Code Review — Haiku Agents + Sonnet Integration

The verify stage uses `dispatch: debate-driven`. FO dispatches haiku review agents (cheap, specialized) BEFORE dispatching you (sonnet, integration). You read their raw findings and classify.

**Architecture:**
```
FO dispatches (selected by pre-scan):
  ├── haiku agents: pr-review-toolkit + trailofbits skills
  │   ↓ all write raw findings to entity ## Haiku Review
  └── YOU (sonnet): pre-scan → read findings → spot-check → classify → verdict
```

### Step 3.1: Pre-Scan + Reviewer Selection (Inline — You Do This Yourself)

Before reading haiku findings, run these mechanical checks AND determine which reviewers FO should have dispatched:

**Mechanical pre-scan:**

1. **Stale references**: For every symbol removed by the diff, grep for remaining references. Hit outside the diff = stale reference finding.
2. **Plan consistency**: Cross-check `git diff --stat` file list against `## Plan` `files_modified`. Files changed but not in plan = unplanned change finding. Files in plan but unchanged = missed task finding.
3. **Constraint check**: If `PRODUCT.md` has `## Constraints`, verify changes don't violate any.
4. **CLAUDE.md rule walk**: For each changed file in the diff, walk dirname upward from the file to the repo root, collecting every `CLAUDE.md` encountered. Read each collected CLAUDE.md. For every rule it defines, check whether the diff violates it.

   ```
   Example: changed file is src/domain/session/watcher.ts
   Walk: src/domain/session/CLAUDE.md → src/domain/CLAUDE.md → src/CLAUDE.md → CLAUDE.md
   Each CLAUDE.md may define rules like "no direct DB access from domain layer",
   "always use Zod for external input validation", etc.
   ```

   Any violation = pre-scan finding with: the CLAUDE.md path, the rule text, the violating file:line from the diff. Severity: BLOCKING (rule uses "must"/"never"/"always") or WARNING (rule uses "prefer"/"should"/"consider").

   **Dedup**: if multiple changed files share the same parent CLAUDE.md, read it once. Cache CLAUDE.md contents during the walk.

**Reviewer selection matrix (FO uses this to decide which haiku agents to dispatch):**

Read `## Size Assessment` from entity and diff content:

```bash
DIFF_FILES=$(git diff {execute_base}..HEAD --name-only)
DIFF_CONTENT=$(git diff {execute_base}..HEAD)
```

#### Always dispatch (all sizes):

| Agent | Skill | What it checks |
|-------|-------|---------------|
| `code-reviewer` | `pr-review-toolkit:code-reviewer` | Diff correctness, match to plan, regressions |

#### Dispatch for M/L:

| Agent | Skill | What it checks |
|-------|-------|---------------|
| `silent-failure-hunter` | `pr-review-toolkit:silent-failure-hunter` | Empty catch blocks, swallowed errors, fallbacks that hide failures |
| `pr-test-analyzer` | `pr-review-toolkit:pr-test-analyzer` | Test coverage quality, missing edge case tests |

#### Dispatch based on diff content (any size):

| Agent | Skill | Trigger condition | Detection |
|-------|-------|------------------|-----------|
| `type-design-analyzer` | `pr-review-toolkit:type-design-analyzer` | New/modified types | `echo "$DIFF_CONTENT" \| grep -E '^\+.*(type \|interface \|enum )' ` |
| `comment-analyzer` | `pr-review-toolkit:comment-analyzer` | Significant comment/doc changes | `echo "$DIFF_CONTENT" \| grep -cE '^\+.*(\/\*\*\|\/\/\/ \|@param\|@returns)' > 3` |
| `code-simplifier` | `pr-review-toolkit:code-simplifier` | Large additions (>100 lines added) | `echo "$DIFF_CONTENT" \| grep -c '^+[^+]' > 100` |
| `insecure-defaults` | `trailofbits:insecure-defaults` | Auth/config/env/secret changes | `echo "$DIFF_FILES" \| grep -iE 'auth\|config\|env\|secret\|middleware\|cors\|csp'` |
| `sharp-edges` | `trailofbits:sharp-edges` | API/route/handler changes | `echo "$DIFF_FILES" \| grep -iE 'route\|api\|handler\|endpoint\|server'` |
| `variant-analysis` | `trailofbits:variant-analysis` | Entity is a bug fix | `grep -i 'source:.*bug\|source:.*fix\|bugfix\|hotfix' {entity_frontmatter}` |
| `differential-review` | `trailofbits:differential-review` | Files with prior changes in last 30 days | `git log --since="30 days ago" --name-only --pretty=format: -- $DIFF_FILES \| sort -u \| wc -l > 0` |

#### Summary by size:

| Size | Mandatory | Content-triggered | Total range |
|------|-----------|-------------------|-------------|
| S (≤3 files) | code-reviewer (1) | 0-4 based on content | 1-5 agents |
| M (4-15 files) | code-reviewer + silent-failure-hunter + pr-test-analyzer (3) | 0-4 based on content | 3-7 agents |
| L (>15 files) | code-reviewer + silent-failure-hunter + pr-test-analyzer + comment-analyzer + code-simplifier (5) | 0-4 based on content | 5-9 agents |

**Cost estimate:** haiku ~$0.05/agent → S: $0.05-0.25, M: $0.15-0.35, L: $0.25-0.45

**Haiku agent prompt template (FO uses this for each dispatched reviewer):**

Each haiku agent receives:
```
You are a specialized code reviewer. Load Skill("{skill-name}") and apply it to this diff.

## Diff
git diff {execute_base}..HEAD

## Rules
- Report raw findings only — no severity, no fix recommendations
- Each finding must include: file:line, exact code snippet (copy-paste, not paraphrased), check name
- Do NOT assign severity — the sonnet verify ensign classifies
- Return empty array [] if no checks trigger
- A false finding is worse than no finding — you will be spot-checked
```

### Step 3.2: Read Haiku Review Findings

Read `## Haiku Review` from the entity file (written by FO-dispatched haiku agents).

Expected finding format from each haiku agent:
```
### {agent-name} ({skill-name})
- file:line — `{exact code snippet}` — {check that triggered}
- file:line — `{exact code snippet}` — {check that triggered}
```

If `## Haiku Review` is missing (FO skipped dispatch, or bare mode):
- Run a single inline review yourself using the diff:
  ```bash
  git diff {execute_base}..HEAD
  ```
  Check: (1) changes match plan, (2) security, (3) dead code, (4) error handling, (5) stale refs.

### Step 3.3: Spot-Check Haiku Citations (Hallucination Guard)

**Before classifying ANY haiku finding, spot-check 2-3 citations:**

1. Pick 2-3 findings at random from haiku output
2. Read the cited file:line
3. Does the code snippet match what's actually in the file?

| Result | Action |
|--------|--------|
| All spot-checks match | Proceed to classification |
| 1 mismatch | Drop that finding, mark `⚠️ hallucination dropped`, check 2 more from same agent |
| > 50% mismatches from one agent | **Discard ALL findings from that agent**, log as Learning: `"haiku {agent-name} hallucinated > 50% — all findings dropped"` |

### Step 3.4: Classify Findings

For each surviving finding (from haiku agents, pre-scan, or inline review), YOU assign severity:

| Severity | Routing |
|----------|---------|
| **BLOCKING** — security hole, broken functionality, data loss risk | NEEDS_FIX → report to FO |
| **WARNING** — potential bug, missing edge case, weak error handling | Log, proceed if no BLOCKING |
| **NIT** — style, naming, minor improvement | Log as non-blocking, auto-create draft entity if warranted |

**If BLOCKING findings exist:**
- Write classification to `## Review Findings`
- Report NEEDS_FIX to FO with specific blocking issues
- FO dispatches fix agent → re-dispatches haiku reviewers → you re-classify
- Max 2 rounds, then escalate to captain

```markdown
## Review Findings
Scope: {N} files, {M} haiku reviewers dispatched (or "inline review — bare mode")

### Pre-scan
- Stale references: {none | list}
- Plan consistency: {all files match | discrepancies}
- Constraint check: {all constraints respected | violations}

### Haiku review (spot-checked)
Spot-check: {N}/{M} citations verified — {all match | N hallucinations dropped}

| Severity | File:Line | Description | Source |
|----------|-----------|-------------|--------|
| BLOCKING | src/api.ts:42 | Silent swallow of 4xx | silent-failure-hunter |
| WARNING | src/types.ts:10 | Loose union type | type-design-analyzer |

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

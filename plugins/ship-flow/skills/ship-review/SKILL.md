---
name: ship-review
description: "Use when verify stage passed and entity is ready for PR creation + documentation updates. Agent-autonomous: creates PR, updates ROADMAP.md and PRODUCT.md, reports token cost."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Review — PR and Documentation

You are running the SHIP stage of ship-flow. Verify has already passed — quality, review, and UAT are done. Your job: create the PR, update project documentation, report costs.

After this stage, FO advances to `done` (terminal) which triggers the merge hook.

## Entity Body Contract

**Schema:** `references/entity-body-schema.yaml` → `stages.ship`

**Reads:** `## Verify Report` (must be PASS), `## Execute Output`, `## Sharp Output`, `## Verify UAT`, `PRODUCT.md`, `ROADMAP.md`, `references/doc-format.md`
**Writes:**
- `## Ship Output` — subsections: PR Draft, ROADMAP.md Update, PRODUCT.md Update, D2 Knowledge Candidates, Token Summary
- `## Ship Report` — status, stage_cost, PR link, token budget/actual, tasks, verify, roadmap, product
**Side effects:**
- `ROADMAP.md` — entity moves from Now → Shipped
- `PRODUCT.md` — new capability + user stories appended

---

## Step 1: Read Verify Results

Record the current time as the stage start timestamp (ISO 8601 format).

Read the entity file. Extract:
- `## Verify Report` — must have `Verdict: PASS`
- `## Execute Output → ### Execution Log` — for PR body (task summary, commit SHAs)
- `## Sharp Output → ### Done Criteria` — for PR body (checkmarks)
- `## Sharp Output → ### Problem` — for PR body
- `## Sharp Output → ### Shape Output` — for user stories to add to PRODUCT.md (if shape ran)
- `## Sharp Output → ### Size Assessment` — for cost summary

**Pre-check**: If `## Verify Report` verdict is not PASS → do NOT proceed. Report back to FO.

---

## Step 2: Create PR

**Do NOT push or create the PR directly.** The `done` stage's merge hook (pr-merge mod) handles push + PR creation + captain approval. Your job is to prepare the PR body and write it to the entity file so the merge hook can use it.

Write `### PR Draft` (under `## Ship Output`) to the entity file:

```markdown
### PR Draft

Title: {entity title}

Body:
## Problem
{from ## Sharp Output → ### Problem}

## User Journey
{from ## Sharp Output → ### User Journey — the end-to-end flow this feature enables}

## Done Criteria + Verification
{Full UAT results table from ## Verify UAT — includes DC number, type, assertion, verify procedure, and result. Reviewer can copy-paste any procedure to reproduce.}

| DC | Type | Assertion | Verify Procedure | Result |
|----|------|-----------|-----------------|--------|
| DC-1 | ui | Detail page with panel | `curl -sf localhost:3000/entity/test \| grep 'comment-panel'` | ✅ |
| DC-2 | api | POST returns 201 | `curl -s -w "%{http_code}" -X POST ...` | ✅ 201 |
| ... | ... | ... | ... | ... |

## Changes
{from ## Execute Output → ### Execution Log — task summary with commit SHAs}

## Quality Gate
{from ## Verify Output → ### Quality Gate — 5-check results}

Entity: #{entity-id}
Ship-flow: sharp → plan → execute → verify → ship (autonomous)
Tracker: {tracker + issue, if set}
Cost: ${token_actual} (budget: ${token_budget})
```

The merge hook reads `## Ship Output → ### PR Draft` to assemble `gh pr create` with the prepared title and body.

---

## Step 3: Update ROADMAP.md

Read `ROADMAP.md` from project root. If it exists:

1. Find the entity in `## Now` table (match by entity slug or title)
2. Remove that row from `## Now`
3. Append a new row to `## Shipped` table. Use the entity's `id` from frontmatter — do NOT invent a new number:
   ```
   | {entity.id} | {entity.title} | {one-sentence from ### Problem, present tense per doc-format.md} | {today's date} | ⏳ |
   ```
   If `{entity.id}` already exists in the Shipped table (cross-workflow collision), append the workflow dir name as suffix: `{id}-{workflow-dir-name}` (e.g., `005-ship-flow`).
4. If `## Cost Calibration` table exists and `token_actual` is known:
   - Increment the size row's Sample count
   - Recalculate Median actual if sample ≥ 3

If ROADMAP.md doesn't exist → skip (no error).

---

## Step 4: Update PRODUCT.md

Read `PRODUCT.md` from project root. If it exists:

**Read `references/doc-format.md` for exact formats.** Follow the derivation rules — do not improvise formats.

1. **Add capability bullet** to `## Current Capabilities`:
   - Find the matching domain subsection (session management, communication, access, etc.)
   - Format: `- {What it does} — {why it matters in ≤10 words} (#{entity-id})`
   - Derivation: if shape ran → from US-1 "I want" clause. If not → from `### Problem` first sentence rewritten as capability.
   - If no matching subsection exists → create one.

2. **Add user story** (JTBD format):
   - If shape ran → copy accepted stories from `## Sharp Output → ### Shape Output`
   - If shape didn't run → generate ONE story from `## Sharp Output → ### Problem` + `## Sharp Output → ### Done Criteria`:
     - Persona: match from PRODUCT.md "Who It Serves" (default: Captain)
     - Action: from Done Criteria's primary observable change
     - Outcome: from Problem's "why it matters"
   - Deduplicate against existing stories.

3. **Update constraints** (if the feature changes any constraint):
   - Rare, but if the feature explicitly relaxes or adds a constraint, update the Constraints table

4. **Cross-check consistency** (from doc-format.md):
   - ROADMAP Shipped "Why it existed" ↔ PRODUCT capability "why it matters" → same idea, different format
   - North Star in PRODUCT.md Vision ↔ ROADMAP.md North Star → must be identical text

If PRODUCT.md doesn't exist → skip (no error).

---

## Step 5: Token Cost Summary

Read `token_actual` from entity frontmatter (accumulated by FO during dispatch).
Read `token_budget` from `## Sharp Output → ### Size Assessment`.

```markdown
### Token Summary
Budget: ${token_budget}
Actual: ${token_actual}
Ratio: {actual/budget}x
```

If ratio > 2.0 → note in Ship Report as "⚠️ over budget".

---

## Step 6: Write Ship Report + Finalize

```markdown
## Ship Report
Verdict: shipped
PR: {pr-url}
Token budget: ${token_budget}
Token actual: ${token_actual}
Tasks: {done}/{total} ({failed} failed, {issues} auto-issues created)
Verify: PASS (quality {5/5}, review {verdict}, UAT {all pass})
ROADMAP.md: updated (Now → Shipped)
PRODUCT.md: updated ({N} capabilities added)
stage_cost: ${ship_cost} (1 dispatch: sonnet)
started_at: "{ISO 8601 timestamp}"
completed_at: "{ISO 8601 timestamp}"
duration_minutes: {number}
```

FO reads `stage_cost:` line and adds to entity frontmatter `token_actual` accumulation. Calculate duration from the recorded start timestamp to now. Write started_at, completed_at, and duration_minutes to the report.

Update entity frontmatter:
```yaml
status: ship
pr: "{pr-number}"
token_actual: {total}
```

Note: Do NOT set `status: done` or `completed:` or `verdict:` — the FO advances to `done` (terminal) after this stage completes, which triggers the merge hook.

### 6.1: Surface D2 Knowledge Candidates

Scan `### Knowledge Captures` sections (in both `## Execute Output` and `## Verify Output`) for `[D2-candidate]` tags (written by execute Step 5.3 and verify Step 4.5).

If D2 candidates exist, include them in the captain notification with a prompt:

> **Knowledge candidates** — these patterns generalized beyond this entity. Add to CLAUDE.md?
> - {D2 candidate 1}
> - {D2 candidate 2}
>
> Reply "yes" to add all, or specify which to accept.

If captain approves (via the next interaction), append accepted patterns to the project's CLAUDE.md in the appropriate section.

If no D2 candidates → skip silently.

---

Notify captain:

> **Shipped: {title}**
> PR: {pr-url}
> Done criteria: {all pass}
> Cost: ${token_actual} (budget: ${token_budget})
> ROADMAP: ✅ updated
> PRODUCT: ✅ updated
> Issues found: {count, with entity refs}
> Knowledge: {D1: N auto-written, D2: M candidates for review | none}

---

## Circuit Breakers

- Verify Report not PASS → do not proceed, report back to FO
- PR creation fails → retry once, then escalate to captain
- ROADMAP/PRODUCT update fails → log as Learning, proceed (non-blocking)
- Token overrun: if token_actual > token_budget × 2 → note in Ship Report

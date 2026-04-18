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

**Reads:** `## Problem`, `## Done Criteria`, `## Execution Log`, `## Verify Report`, `## Size Assessment`, `## Shape Output` (if exists), `PRODUCT.md`, `ROADMAP.md`, `references/doc-format.md` (Shipped row + capability bullet + user story derivation formats)
**Writes (all mandatory):**
- `## Ship Report` — verdict, PR link, token actual, task summary
- `## Token Summary` — budget vs actual with ratio
**Side effects:**
- `ROADMAP.md` — entity moves from Now → Shipped
- `PRODUCT.md` — new capability + user stories appended
**Optional writes:**
- `## Learnings` — insights discovered during ship (append-only)

---

## Step 1: Read Verify Results

Read the entity file. Extract:
- `## Verify Report` — must have `Verdict: PASS`
- `## Execution Log` — for PR body (task summary, commit SHAs)
- `## Done Criteria` — for PR body (checkmarks)
- `## Problem` — for PR body
- `## Shape Output` — for user stories to add to PRODUCT.md (if shape ran)
- `## Size Assessment` — for cost summary

**Pre-check**: If `## Verify Report` verdict is not PASS → do NOT proceed. Report back to FO.

---

## Step 2: Create PR

```bash
BRANCH=$(git branch --show-current)
git push origin "${BRANCH}"

gh pr create \
  --title "{entity title}" \
  --body "## Problem
{from entity ## Problem}

## Done Criteria
{from entity, with checkmarks from ## UAT Results}

## Changes
{from ## Execution Log — task summary with commit SHAs}

## Verification
{from ## Verify Report — quality/review/UAT summary}

Entity: #{entity-id}
Ship-flow: sharp → plan → execute → verify → ship (autonomous)" \
  --base main
```

---

## Step 3: Update ROADMAP.md

Read `ROADMAP.md` from project root. If it exists:

1. Find the entity in `## Now` table (match by entity slug or title)
2. Remove that row from `## Now`
3. Append a new row to `## Shipped` table:
   ```
   | {id} | {title} | {one-sentence from ## Problem} | {today's date} | ⏳ 待驗證 |
   ```
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
   - Derivation: if shape ran → from US-1 "I want" clause. If not → from `## Problem` first sentence rewritten as capability.
   - If no matching subsection exists → create one.

2. **Add user story** (JTBD format):
   - If shape ran → copy accepted stories from `## Shape Output`
   - If shape didn't run → generate ONE story from `## Problem` + `## Done Criteria`:
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
Read `token_budget` from `## Size Assessment`.

```markdown
## Token Summary
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
```

Update entity frontmatter:
```yaml
status: ship
pr: "{pr-number}"
token_actual: {total}
```

Note: Do NOT set `status: done` or `completed:` or `verdict:` — the FO advances to `done` (terminal) after this stage completes, which triggers the merge hook.

Notify captain:

> **Shipped: {title}**
> PR: {pr-url}
> Done criteria: {all pass}
> Cost: ${token_actual} (budget: ${token_budget})
> ROADMAP: ✅ updated
> PRODUCT: ✅ updated
> Issues found: {count, with entity refs}

---

## Circuit Breakers

- Verify Report not PASS → do not proceed, report back to FO
- PR creation fails → retry once, then escalate to captain
- ROADMAP/PRODUCT update fails → log as Learning, proceed (non-blocking)
- Token overrun: if token_actual > token_budget × 2 → note in Ship Report

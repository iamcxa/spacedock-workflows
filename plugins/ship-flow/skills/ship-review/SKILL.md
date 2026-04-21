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

**Reads:** `## Verify → ### Verdict` (must have `status: passed`) — for legacy entities, fall back to `## Verify Report` H2. Also: `## Execute Output`, `## Sharp Output` (including optional `### Architecture Impact`), `## Verify → ### UAT` (or legacy `## Verify UAT`), `## Verify → ### Quality Gate` (or legacy `## Verify Output → ### Quality Gate`), `PRODUCT.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `references/doc-format.md`
**Writes:** single `## Ship` section with subsections (post-2026-04-19 D1 consolidation):
- `### PR Draft` — title + body (consumed by pr-merge mod)
- `### ROADMAP.md Update` — note of what was moved (conditional)
- `### PRODUCT.md Update` — capabilities/stories added (conditional)
- `### D2 Knowledge Candidates` — D2-tagged items surfaced from execute/verify (conditional)
- `### Token Summary` — budget vs actual + ratio
- `### Verdict` — status / PR link / stage cost / timestamps (replaces legacy `## Ship Report`)

> Pre-2026-04-19 layout used `## Ship Output` + separate `## Ship Report`. Pr-merge mod accepts both layouts. New entities use single `## Ship`.

**Side effects:**
- `ROADMAP.md` — entity moves from Now → Shipped
- `PRODUCT.md` — new capability + user stories appended

---

## Step 1: Read Verify Results

**Section extraction:** When reading a specific section from an entity file, prefer tag-based extraction over H2 boundary grep:
```bash
bash plugins/ship-flow/lib/extract-section.sh {entity-file} {section-tag}
```
Falls back to H2 boundary regex automatically for legacy (untagged) entities.

Record the current time as the stage start timestamp (ISO 8601 format).

Read the entity file. Extract (try new layout first, fall back to legacy):
- `## Verify → ### Verdict` — must have `status: passed` (or `Verdict: PASS`). Legacy fallback: `## Verify Report` with `Verdict: PASS`.
- `## Execute Output → ### Execution Log` — for PR body (task summary, commit SHAs)
- `## Sharp Output → ### Done Criteria` — for PR body (checkmarks)
- `## Sharp Output → ### Problem` — for PR body
- `## Sharp Output → ### Shape Output` — for user stories to add to PRODUCT.md (if shape ran)
- `## Sharp Output → ### Size Assessment` — for cost summary

**Layout detection** (do this once at the top of Step 1):
```bash
if grep -q '^## Verify$' {entity_file}; then
  layout=new   # post-2026-04-19: ## Verify with subsections
else
  layout=legacy  # ## Verify Output / ## Verify Report / ## Verify UAT as separate H2
fi
```

Use `layout` to pick the right grep target throughout Step 2.

**Pre-check**: If verdict is not `passed`/`PASS` → do NOT proceed. **Write `## Ship` with `### Verdict` containing `status: blocked` and reason (e.g., "Verify verdict: {actual_verdict}, expected passed")** to the entity file, then report back to FO. The FO output-validation gate requires the `## Ship → ### Verdict` subsection to exist (or legacy `## Ship Report` for older entities). Never exit without writing them.

---

## Step 1.5: Invoke architecture-canon mod (#060)

Runs BEFORE Step 2 (PR-body construction) so architectural commits land on the branch before the PR is drafted, and the PR body can reference the resulting commit SHAs.

**Trigger check:**
```bash
bash plugins/ship-flow/lib/extract-section.sh "$ENTITY_FILE" architecture-impact 2>/dev/null | grep -qE "^after:[[:space:]]*\|"
```
If no `architecture-impact` section OR `after:` block is empty → skip this step silently (the mod noops internally too; double-checking here saves one subshell).

**When triggered** — invoke the mod with the entity file passed via env:
```bash
ENTITY_FILE="$ENTITY_FILE" bash docs/ship-flow/_mods/architecture-canon.md
```

The mod:
1. Freshness-checks the entity's captured `before` against current `ARCHITECTURE.md` (exit 1 with `freshness` diagnostic if stale)
2. Atomically patches `target_section` via `patch-map.sh` with read-first CAS (one commit: `docs(architecture): #{id} — {summary}`)
3. Appends a new row to the Decisions table via extract-then-patch (second commit: `docs(architecture-index): #{id}`)

**On mod success (exit 0):**
- Capture the two new commit SHAs for the PR body:
  ```bash
  ARCH_COMMIT=$(git log -2 --format=%H --grep='^docs(architecture): #' | head -1)
  ADR_COMMIT=$(git log -2 --format=%H --grep='^docs(architecture-index): #' | head -1)
  ```
- Note for Step 2 PR body to include the `## Architecture Changes` section.

**On mod failure (exit non-zero):**
- HALT ship-review immediately. Do NOT advance to Step 2.
- Write `## Ship → ### Verdict` with `status: blocked` and reason `"architecture-canon mod failed: exit {rc} (see journal for mod stderr)"`.
- Entity stays at `verify` state; captain must reconcile (most commonly: re-extract `before` from current `ARCHITECTURE.md` because a parallel session patched it after sharp).
- Exit codes: 1 = freshness / missing fields, 6 = CAS mismatch, 9 = mermaid validation.

**Captain visibility** — report the two new commit SHAs (or halt reason) back to FO after this step.

---

## VCS Detection Preamble

Before any PR-related operation, resolve the VCS tool by reading the project context:

### Step V1: Detect VCS Provider

```bash
git remote -v 2>/dev/null | grep -q "github\.com" && echo "vcs=github" || \
git remote -v 2>/dev/null | grep -q "gitlab\.com" && echo "vcs=gitlab" || \
echo "vcs=unknown"
```

### Step V2: Check README Frontmatter Override

Read the workflow README at `docs/{workflow}/README.md`. If the frontmatter contains a `commands:` block with VCS commands, those values override auto-detection:
```yaml
commands:
  pr_create: "gh pr create"   # overrides auto-detected VCS command
  pr_view: "gh pr view"
  pr_comment: "gh pr comment"
  pr_close: "gh pr close"
```

### Step V3: Resolve VCS Command Variables

| Variable | github | gitlab |
|----------|--------|--------|
| `{commands.pr_create}` | `gh pr create` | `glab mr create` |
| `{commands.pr_view}` | `gh pr view` | `glab mr view` |
| `{commands.pr_comment}` | `gh pr comment` | `glab mr comment` |
| `{commands.pr_close}` | `gh pr close` | `glab mr close` |

If vcs is `unknown` → stop and ask captain to add `commands:` VCS block to workflow README frontmatter.

README frontmatter `commands:` takes precedence over the table above.

---

## Step 2: Create PR

**Section tagging (mandatory):** Wrap ## Ship and all subsections with their tags. Example:

```markdown
<!-- section:ship -->
## Ship

<!-- section:pr-draft -->
### PR Draft
{content}
<!-- /section:pr-draft -->

<!-- section:roadmap-update -->
### ROADMAP.md Update
{content}
<!-- /section:roadmap-update -->

<!-- section:product-update -->
### PRODUCT.md Update
{content}
<!-- /section:product-update -->

<!-- section:d2-knowledge-candidates -->
### D2 Knowledge Candidates
{content}
<!-- /section:d2-knowledge-candidates -->

<!-- section:token-summary -->
### Token Summary
{content}
<!-- /section:token-summary -->

<!-- section:ship-verdict -->
### Verdict
{fields}
<!-- /section:ship-verdict -->

<!-- /section:ship -->
```

Tag list: `ship` (impl), `pr-draft` (impl), `roadmap-update` (impl), `product-update` (impl), `d2-knowledge-candidates` (impl), `token-summary` (impl), `ship-verdict` (impl)

**Do NOT push or create the PR directly.** The `done` stage's merge hook (pr-merge mod) handles push + PR creation + captain approval. Your job is to prepare the PR body and write it to the entity file so the merge hook can use it.

Write `### PR Draft` (under `## Ship`) to the entity file:

```markdown
### PR Draft

Title: {entity title}

Body:
## Problem
{from ## Sharp Output → ### Problem}

## User Journey
{from ## Sharp Output → ### User Journey — the end-to-end flow this feature enables}

## Done Criteria + Verification
{Full UAT results table — from `## Verify → ### UAT` (new layout) or `## Verify UAT` (legacy). Includes DC number, type, assertion, verify procedure, and result. Reviewer can copy-paste any procedure to reproduce.}

| DC | Type | Assertion | Verify Procedure | Result |
|----|------|-----------|-----------------|--------|
| DC-1 | ui | Detail page with panel | `curl -sf localhost:3000/entity/test \| grep 'comment-panel'` | ✅ |
| DC-2 | api | POST returns 201 | `curl -s -w "%{http_code}" -X POST ...` | ✅ 201 |
| ... | ... | ... | ... | ... |

## Changes
{from ## Execute Output → ### Execution Log — task summary with commit SHAs}

## Architecture Changes          ← include only if architecture-canon mod ran in Step 1.5
- Patched `ARCHITECTURE.md` → `{target_section}`: {summary} ({ARCH_COMMIT short-SHA})
- Appended Decisions index row for #{entity-id} ({ADR_COMMIT short-SHA})

## Quality Gate
{from `## Verify → ### Quality Gate` (new layout) or `## Verify Output → ### Quality Gate` (legacy) — 5-check results}

Entity: #{entity-id}
Ship-flow: sharp → plan → execute → verify → ship (autonomous)
Tracker: {tracker + issue, if set}
Cost: ${token_actual} (budget: ${token_budget})
```

The merge hook reads `## Ship → ### PR Draft` (new layout) or `## Ship Output → ### PR Draft` (legacy) to assemble the PR creation command (resolved via VCS Detection Preamble in pr-merge mod) with the prepared title and body.

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

If ratio > 2.0 → note in Verdict as "⚠️ over budget".

---

## Step 6: Write Verdict + Finalize

Append `### Verdict` subsection to the entity's `## Ship` section. This replaces legacy top-level `## Ship Report`.

```markdown
### Verdict
status: shipped
PR: {pr-url}
Token budget: ${token_budget}
Token actual: ${token_actual}
Tasks: {done}/{total} ({failed} failed, {issues} auto-issues created)
Verify: PASS (quality {5/5}, review {verdict}, UAT {all pass})
ROADMAP.md: updated (Now → Shipped) [omit line if no update]
PRODUCT.md: updated ({N} capabilities added) [omit line if no update]
stage_cost: ${ship_cost} (1 dispatch: sonnet)
started_at: "{ISO 8601 timestamp}"
completed_at: "{ISO 8601 timestamp}"
duration_minutes: {number}
```

FO reads `status:` line (grep `^status:`) for the lifecycle gate and `stage_cost:` line for `token_actual` accumulation. Calculate duration from the recorded start timestamp to now.

> Backward compat: pre-2026-04-19 entities used top-level `## Ship Report`. Pr-merge mod accepts both layouts. New entities use `## Ship → ### Verdict`.

**Frontmatter write scope — ONLY `token_actual`.**

The ship ensign may update exactly one frontmatter field:

```yaml
token_actual: {total}
```

**Do NOT write these fields** — they are FO-owned and set at terminal transition (FO advances `ship` → `done` after confirming ship-stage output is clean, or after captain approval in the pr-merge merge-hook):

- `status` — FO advances via `status --set status={next_stage}` (ensign NEVER sets `shipped`; that term isn't even a valid stage in ship-flow)
- `completed` — FO auto-fills ISO 8601 timestamp at terminal transition
- `verdict` — FO sets `PASSED` (not `shipped`) at terminal transition
- `pr` — pr-merge mod's merge hook sets this after `gh pr create` / `glab mr create`; ship ensign does not touch
- `worktree` — FO clears at terminal transition

**Entity body write scope — worktree copy ONLY.**

Ship-stage body content (`## Ship` section with all its subsections) must be written to the **worktree copy** of the entity file (inside `.worktrees/{worker-key}-{slug}/docs/{workflow}/{slug}.md`), NEVER directly to the main-branch entity file. The FO's merge step will bring your body content onto main via the worktree merge; direct writes to main duplicate content and bypass worktree ownership.

If your dispatch prompt gives you the main-branch path for the entity file, use it only for READING context (`## Sharp Output`, `## Plan Output`, `## Verify` verdict). For WRITING, use the worktree copy path explicitly.

### 6.1: Surface D2 Knowledge Candidates

Scan `### Knowledge Captures` sections (in `## Execute Output` and `## Verify` (new layout) or `## Verify Output` (legacy)) for `[D2-candidate]` tags (written by execute Step 5.3 and verify Step 4.5).

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

- Verify verdict not `passed`/`PASS` (whether new `## Verify → ### Verdict` or legacy `## Verify Report`) → do not proceed, report back to FO
- PR creation fails → retry once, then escalate to captain
- ROADMAP/PRODUCT update fails → log as Learning, proceed (non-blocking)
- Token overrun: if token_actual > token_budget × 2 → note in `## Ship → ### Verdict` (or legacy `## Ship Report`)

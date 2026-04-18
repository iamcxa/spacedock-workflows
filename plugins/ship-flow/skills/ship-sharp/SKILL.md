---
name: ship-sharp
description: "Use when sharpening a feature before autonomous pipeline execution. Captain-facing stage: auto-detects directive maturity (shape vs sharp path), applies Musk-style critical questioning, assigns size (S/M/L), scoring gate. Only human touchpoint in ship-flow."
user-invocable: true
argument-hint: "[entity-slug]"
---

# Ship-Sharp — Shape + Sharp: Define What to Ship and Why

You are running the SHARP stage of ship-flow. This is the captain's only interaction with the pipeline — after this, agents run autonomously to ship.

**Shape and sharp are different actions combined in one stage:**
- **Shape** = expand a vague idea into concrete form (problem statement, user stories, scope boundary). Clay, forming.
- **Sharp** = challenge and reduce a concrete directive to its minimum (Musk questioning, scoring gate, size triage). Knife, sharpening.

Your job: make sure we're building the right thing, the smallest version of it, and that it's worth doing at all.

## Entity Body Contract

**Schema:** `references/entity-body-schema.yaml` → `stages.sharp`

**Reads:** entity frontmatter, `PRODUCT.md`, `ROADMAP.md`, `references/doc-format.md`, recent shipped entities
**Writes:**
- `## Sharp Output` — subsections: Shape Output (conditional), Roadmap Position, Problem, Done Criteria (typed), User Journey, Journey→DC Mapping, Size Assessment, Musk Audit, Scoring Gate, Project Skills
- `## Sharp Report` — status, stage_cost, path (shape+sharp / sharp-only / escape-hatch)

---

## Step 0: Detect Directive Maturity (Shape vs Sharp Router)

Read the directive text. Apply hedge-word detection to determine maturity:

**Concrete signals** (→ skip shape, go directly to Step 1 Sharp):
- References specific file paths, line numbers, or function names
- Describes a specific bug with reproduction steps
- Contains testable acceptance criteria
- Uses precise technical language ("POST /api/X returns 201", "fix race condition in Y")

**Vague signals** (→ run shape first, then sharp):
- Hedge words: "改善", "更好", "可能需要", "improve", "better experience", "explore", "might need"
- Abstract goals without measurable outcomes
- No file paths, no specific behavior described
- Problem framing unclear ("make collaboration better", "improve the workflow")

**Escape hatch** (→ skip entire stage):
- Directive is < 80 chars AND contains: `fix`, `typo`, `rename`, `bump`, `patch`, `bugfix`, `hotfix` as whole word
- Emit: `sharp unnecessary — run ship-plan directly with inline sharp`
- EXIT. Do NOT create shape or sharp output.

**Decision output**: Announce the path to captain:
- "Directive is concrete — proceeding directly to sharp."
- "Directive needs shaping — running shape phase first to define scope."
- "Small fix detected — skipping sharp, route to plan."

---

## Shape Phase (Steps S1-S3) — Only When Step 0 Routes Here

### Step S1: Frame the Problem

Ask the captain to clarify the problem space. Present 2-3 candidate problem statements:

Each candidate is a 3-6 sentence paragraph describing:
- The gap (what's missing or broken)
- Who experiences it (specific role/persona)
- Why it matters now (urgency driver)

**Do NOT include solution language in problem statements.**

Present candidates in the chat thread with full text, then ask:
- "Which problem statement frames this best?" (options: A / B / C / revise)

If captain picks "revise" — iterate with their feedback until they accept. Write accepted statement.

### Step S2: Generate User Stories

Based on the accepted problem statement, generate 3-5 user stories:
- Literal format: "As a {role}, I want {action}, so that {value}"
- Numbered US-1 through US-N

Present all stories, then for each ask: Accept / Edit / Drop.
- If captain drops below 3 stories, generate replacements.
- Final accepted set must be 3-5 stories.

### Step S3: Draft Scope Boundary

Based on problem + stories, draft two lists:

**Scope: In** — concrete deliverables, each specific enough to verify. Bias toward minimal viable scope:
- Prefer reuse over greenfield
- Prefer hook points over new architecture
- Each bullet must be verifiable

**Scope: Out** — explicit exclusions with WHY in parenthetical. At least 3 items of the form "could expand to X but not doing X because Y".

Present In/Out to captain. Ask: "Accept all / Edit / Prune" for each list.

**Write `### Shape Output` (under `## Sharp Output`)** with accepted Problem Statement, User Stories, and Scope In/Out.

---

## Step 0.5: Entity ID Validation

If the entity file has no `id` field or `id` is empty in frontmatter, assign one:

```bash
python3 {spacedock_plugin_dir}/skills/commission/bin/status --workflow-dir {workflow_dir} --next-id
```

Write the returned ID into the entity frontmatter. This prevents ID collisions across concurrent sessions.

If `id` is already set, verify it's not already used:
```bash
grep -rl "^id: \"{entity_id}\"" {workflow_dir}/*.md | grep -v {entity_file}
```
If collision found → reassign via `--next-id`.

## Step 1: Load Context

1. Read the entity file (from slug or current dispatch)
2. Read `PRODUCT.md` from project root **if it exists** — understand what the product is now (capabilities, constraints, personas, vision). Do NOT create if missing.
3. Read `ROADMAP.md` from project root **if it exists** — understand where the product is going (Now/Next/Later, Not Doing, North Star). Do NOT create if missing. Note in ## Roadmap Position if either file is absent.
4. Read recent shipped entities (last 5) for pattern awareness
5. Scan project-scope plugins for available domain skills:
   ```bash
   claude plugins list --scope project 2>/dev/null
   ```

**Context usage**: PRODUCT.md tells you "does this feature fit the current product?" (constraints, personas, architecture). ROADMAP.md tells you "does this feature fit the plan?" (Not Doing conflicts, dependency on unshipped work, North Star alignment).

## Step 2: Musk Audit (Expanded)

Ask the captain these questions. Do NOT skip any. Wait for answers one at a time.

**Question 1 — Problem**: What specific problem does this solve? Who feels the pain today?
- If shape ran: "The Shape Output says {problem statement} — is that still accurate?"

**Question 2 — Fastest Path**: Is this the shortest path to solving that pain? What's the version that ships in 1 day instead of 1 week?

**Question 3 — Purpose**: If we don't do this, what happens? If the answer is "nothing much" — challenge whether it should exist.

**Question 4 — Position**: Based on ROADMAP.md, where does this fit? Does it conflict with anything in "Not Doing"? Does it depend on something not yet shipped?

After each answer, push back if the answer is vague. Use concrete follow-ups:
- "You said 'improve performance' — what's the current latency and what's the target?"
- "You said 'users need this' — which user asked for it and when?"
- "You said 'it's important' — more important than {top In-Flight item}?"

### Step 2.5: Gap-to-Goal Pressure Test

After the 4 Musk questions, run this 3-question pressure test:

1. **Goal restatement**: "Based on everything above, state in one sentence what goal you're reaching for. Is that still what you want?"
2. **Current gap**: "Given the current codebase, what is the *specific* gap between now and that goal?"
3. **Fastest path?**: "Does the current scope close that gap the fastest way? Consider: (a) reuse an existing primitive, (b) push work upstream, (c) defer scope to a later entity, (d) pick a subset that unblocks 80% of the goal."

If captain identifies a simpler path → loop back to revise scope (or Shape Output if shape ran).

### Step 2.7: Per-Bullet Musk Reverse-Thinking (M/L only)

**Skip for Size S** (≤ 3 scope bullets — already minimal).

For each scope bullet (from `### Shape Output`'s Scope: In, or from captain's answers):

Apply 3 questions:
1. Is this delivering a real outcome, or shipping an empty framework?
2. Does this require evidence that doesn't exist yet (dogfood, user feedback)? → DEFER
3. If I delete this, does the 80% path still work?

Rate each bullet: **KEEP / DEFER / DELETE** with one-line rationale.

Present to captain: "Accept recommendations / Keep original / Partial — specify"
- DEFER items → note for Phase 2
- DELETE items → discard (not moved to Out)

### Step 2.8: User Journey Walkthrough (M/L only)

**Skip for Size S** — S-size directives don't have cross-boundary integration risk.

After scope bullets are finalized (KEEP/DEFER/DELETE), narrate the complete end-to-end user journey assuming the feature is shipped. **This journey becomes the source of Done Criteria and UAT verification.**

> "Walk me through this: {persona} wants to {goal}. Starting from {entry point}, step by step, what happens?"

For each step in the journey, produce a structured record:

```markdown
### User Journey

Persona: {from PRODUCT.md or `### Shape Output`}
Goal: {what they're trying to accomplish}
Entry point: {where they start}

| # | Step | Type | Boundary | Risk |
|---|------|------|----------|------|
| 1 | Open dashboard, see entity detail | ui | — | — |
| 2 | Click comment panel, type text, submit | ui | — | — |
| 3 | POST /api/comments → 201 + ID | api | frontend → API | integration |
| 4 | Comment appears in panel (SSE update) | ui | API → SSE → frontend | integration |
| 5 | Claude receives notification within 5s | cli | API → notification | integration |
```

**Type** is one of: `cli`, `api`, `ui`, `skill`, `e2e`. This type carries through to Done Criteria and all downstream verification.

**Boundary** marks where data crosses a system boundary — these are integration risk points that need extra test coverage.

For each step, check:
1. **Does the architecture support this step?** If not → flag as architecture gap
2. **Where does data cross a boundary?** → mark in Boundary column
3. **Is there a simpler alternative?** (e.g., "if we already git push, do we need a sync mechanism?")

**If shape ran**, generate one journey per user story (US-1..US-N). Multiple journeys are fine — each produces its own DC items.

**Present findings to captain:**

> Journey walkthrough revealed:
> - Step {N}: {issue description} — {architecture gap | integration risk | simpler alternative}
>
> Revise scope? (yes → loop back to scope / no → proceed)

**Why this step exists:** Scope bullets are atomic — they pass review individually but may not compose. User journeys are integration tests for the design. They catch cross-boundary issues that per-bullet analysis misses.

## Step 3: Size Triage (Evidence-Based)

**Do NOT ask the captain to guess.** Run a 10-second probe, present evidence, then classify.

### Step 3.1: Quick Codebase Probe

Extract keywords from `### Problem` (function names, file names, module names, error messages). Then:

```bash
# Count affected files
grep -rl "{keyword1}\|{keyword2}\|{keyword3}" {project_root}/src/ {project_root}/lib/ {project_root}/plugins/ 2>/dev/null | sort -u | wc -l

# Count affected directories (modules)
grep -rl "{keyword1}\|{keyword2}" {project_root}/src/ {project_root}/lib/ {project_root}/plugins/ 2>/dev/null | xargs -I{} dirname {} | sort -u | wc -l

# Check if tests exist
grep -rl "{keyword1}\|{keyword2}" {project_root}/tests/ {project_root}/**/*.test.* 2>/dev/null | wc -l
```

### Step 3.2: Auto-Classify from Evidence

| Evidence | Size | Pipeline behavior |
|----------|------|------------------|
| ≤ 3 files, 1 directory, tests exist | **S** | Plan: inline (no research). Execute: single agent. |
| 4-15 files, 2-4 directories | **M** | Plan: 1-2 researchers + reviewer. Execute: ensign swarm. |
| > 15 files, or 5+ directories, or no tests (need to build test infra) | **L** | Plan: full research team + reviewer. Execute: large swarm. |

### Step 3.3: Present to Captain

Show the probe evidence and classification:

> **Size probe:**
> - Files matching: {N} ({list top 5})
> - Directories: {N} ({list})
> - Existing tests: {N files}
>
> **Auto-classification: {S/M/L}** — {reasoning from evidence}
>
> Confirm, or override with reason?

Captain can override but must give a reason (not just "feels like S").

### Step 3.4: Token Budget

| Size | Budget | Agent dispatches |
|------|--------|-----------------|
| S | ~$2-5 | 1-2 |
| M | ~$8-15 | 5-8 |
| L | ~$30-50 | 12-20 |

Note: plan stage may re-evaluate size after research (Step 2.5 in ship-plan). This is the initial estimate.

## Step 4: Done Criteria (Derived from Journey)

**Done Criteria are derived from the User Journey, not invented independently.** Each journey step becomes one or more typed Done Criteria.

### 4.1: Auto-Generate from Journey

For each step in `### User Journey`, generate a typed Done Criterion:

```markdown
### Done Criteria

- [ ] `ui` — DC-1: Entity detail page loads with comment panel visible (journey step 1)
- [ ] `ui` — DC-2: Comment panel accepts text input and has submit button (journey step 2)
- [ ] `api` — DC-3: POST /api/comments returns 201 with comment ID (journey step 3)
- [ ] `ui` — DC-4: Comment appears in panel without page refresh (journey step 4)
- [ ] `cli` — DC-5: bun test passes notification test — Claude receives within 5s (journey step 5)
```

Each criterion must be:
- **Typed** — one of: `cli`, `api`, `ui`, `skill`, `e2e`
- **Observable** — can be verified by running a command, hitting an endpoint, or checking a page
- **Specific** — no "works correctly" or "is fast enough"
- **Traceable** — references the journey step it came from

**For S-size** (no journey): captain defines criteria directly with types. Still typed, still traceable (to `### Problem` instead of journey).

### 4.2: Journey → DC Mapping Table

Write the mapping so downstream stages can trace from journey → criterion → task → verification:

```markdown
### Journey → DC Mapping

| Journey Step | DC | Type | Boundary | Verify hint |
|---|---|---|---|---|
| 1. Open dashboard | DC-1 | ui | — | curl route, check 200 + content |
| 2. Submit comment | DC-2, DC-3 | ui, api | frontend → API | form element check + curl POST |
| 3. See update | DC-4 | ui | API → SSE → frontend | SSE event or poll check |
| 4. Claude notified | DC-5 | cli | API → notification | bun test with timeout |
```

The **Verify hint** column is a suggestion for plan stage — plan will fill in the exact command. Sharp doesn't need to know the exact command, just the verification approach.

### 4.3: Captain Review

Present the auto-generated criteria to captain:

> **Done Criteria derived from user journey:**
> {list}
>
> Add, edit, or remove any? Each must be typed (`cli`/`api`/`ui`/`skill`/`e2e`) and traceable to a journey step.

Captain can add criteria not covered by the journey (e.g., `cli` — "existing tests don't regress"). These get `(added by captain)` instead of a journey step reference.

## Step 4.5: Dependencies and Tracking

### Dependencies
Ask captain:
- "Does this depend on any other entity finishing first?" → populate `depends-on` in frontmatter
- "Is this part of a larger epic?" → populate `parent` in frontmatter

If captain names dependencies, verify they exist:
```bash
ls docs/ship-flow/{dependency-slug}.md 2>/dev/null
```
If dependency doesn't exist → warn captain ("Entity {slug} not found — create it first?").

### Issue Tracker Binding
Ask captain:
- "Link to an existing issue? (GitHub #number, Linear PROJ-123, or skip)"

If provided:
- Detect provider from format: `#42` or `owner/repo#42` → `tracker: gh`. `PROJ-123` pattern → `tracker: linear`.
- Write `tracker`, `issue`, and `external_id` to frontmatter.
- If `tracker: linear` and Linear MCP is available, verify the issue exists via `mcp__claude_ai_Linear__get_issue`.

If skipped → leave fields empty (entity is captain-only, no external tracker).

## Step 5: Scoring Gate

Present the full assessment:

> **Feature**: {title}
> **Problem**: {one sentence}
> **Size**: {S/M/L} — estimated {budget}
> **Done Criteria**: {list}
> **Roadmap Position**: {where it fits}
> **Shape path**: {ran shape / skipped — direct sharp}
> **Musk verdict**: {bullets kept/deferred/deleted if M/L}
> **Dependencies**: {depends-on list, or "none"}
> **Parent epic**: {parent ID, or "standalone"}
> **Tracker**: {gh #42 / linear PROJ-123 / none}
>
> **Ship this?** (yes → advance to plan / no → reject to draft / split → decompose)

If captain says **split** — help decompose into smaller entities, create each as draft, then let captain pick which to sharp first.

If captain says **no** — set entity verdict to `rejected`, add to ROADMAP.md "Not Doing" with reason.

If captain says **yes** — advance.

## Step 6: Write Entity Sections

Write these sections to the entity file:

```markdown
## Sharp Output

### Shape Output          ← only if shape phase ran
Problem Statement: {accepted statement}
User Stories:
- US-1: As a {role}, I want {action}, so that {value}
- ...
Scope In:
- {bullet 1}
- ...
Scope Out:
- {exclusion 1} (why)
- ...

### Roadmap Position
{Where this fits in the project, dependencies, related shipped features}

### Problem
{Specific problem statement — from ### Shape Output if shape ran, or from Musk audit Q1}

### Done Criteria
- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] {criterion 3}

### Size Assessment
Size: {S/M/L}
Token budget: {estimate}
Reasoning: {why this size}
```

Update entity frontmatter:
```yaml
token_budget: {estimate in USD}
parent: "{epic entity ID, or omit}"
depends-on: ["{entity-id-1}", "{entity-id-2}"]  # or omit if none
tracker: "{gh|linear}"  # or omit if no external tracker
issue: "{#42 or PROJ-123}"  # or omit
external_id: "{full external reference}"  # or omit
```

Continue writing body sections:

```markdown

### Musk Audit
- Fastest path: {captain's answer}
- Purpose: {what happens if we don't}
- Position: {roadmap fit}
- Gap-to-goal: {goal → gap → path assessment}
- Per-bullet audit: {KEEP/DEFER/DELETE verdicts, or "S — skipped"}

### Scoring Gate
Result: PASS
Score: {0.0-1.0}

### Project Skills
{List available project-scope skills relevant to this feature}
```

### Side Effects (after writing entity sections)

**ROADMAP.md** (if exists):
1. Add entity to `## Now` table: `| {slug} | {size} | {one-sentence from Problem} | {today} |`
2. If entity was in `## Next` or `## Later` → remove it from there

**PRODUCT.md** — do NOT modify during sharp. Only ship-review writes to PRODUCT.md after verification passes.

## Stage Cost

Sharp is captain-interactive (no subagent dispatch). Write `## Sharp Report` at end of entity body:

```
## Sharp Report
status: passed
stage_cost: $0.50 (1 session: opus interactive)
path: {shape+sharp | sharp-only | escape-hatch}
```

FO reads `status:` and `stage_cost:` lines for dispatch decisions and `token_actual` accumulation.

## Circuit Breakers

- If captain can't answer Question 1 (what problem?) after 2 attempts → suggest the entity isn't ready. Move back to draft.
- Shape phase: if captain rejects all 3 problem statements and can't articulate what they want → "This directive needs more thinking. Save as draft and revisit."
- Decomposition: if shape reveals N distinct features → emit "decomposition recommended — directive spans N features. Split into N entities and sharp each."

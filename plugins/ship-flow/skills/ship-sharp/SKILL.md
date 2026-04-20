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

Record the current time as the stage start timestamp (ISO 8601 format).

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

**Section extraction:** When reading a specific section from an entity file, prefer tag-based extraction over H2 boundary grep:
```bash
bash plugins/ship-flow/lib/extract-section.sh {entity-file} {section-tag}
```
Falls back to H2 boundary regex automatically for legacy (untagged) entities.

1. Read the entity file (from slug or current dispatch)
2. Read `PRODUCT.md` from project root **if it exists** — understand what the product is now (capabilities, constraints, personas, vision). Do NOT create if missing.
3. Read `ROADMAP.md` from project root **if it exists** — understand where the product is going (Now/Next/Later, Not Doing, North Star). Do NOT create if missing. Note in ## Roadmap Position if either file is absent.
4. Read recent shipped entities (last 5) for pattern awareness
5. Scan project-scope plugins for available domain skills:
   ```bash
   claude plugins list --scope project 2>/dev/null
   ```

**Context usage**: PRODUCT.md tells you "does this feature fit the current product?" (constraints, personas, architecture). ROADMAP.md tells you "does this feature fit the plan?" (Not Doing conflicts, dependency on unshipped work, North Star alignment).

### Step 1.1: Parent Epic Context (child entities only)

**Skip when:** `parent:` frontmatter field is empty or absent.

**When `parent:` is set:**

1. Resolve the parent entity file:
   ```bash
   grep -rl "^id: \"${parent_id}\"" {workflow_dir}/*.md | head -1
   ```
2. Read the parent file. Extract `## Epic Context`:
   - `### Architecture Decisions` — ADRs this child must respect
   - `### Cross-Entity Contracts` — contracts this child must implement
   - `### Entity Decomposition` — find this child's row (its assigned vertical slice)
   - `### Shared Research` — prior research to reuse (avoid re-researching what the epic already covered)

3. Write `## Parent Context` to the child entity body:
   ```markdown
   ## Parent Context

   Epic: {parent_slug} (#{parent_id})
   Inherited decisions:
   {3-5 ADR bullets from parent ### Architecture Decisions that apply to this child}
   Contracts to implement:
   {contract bullets from parent ### Cross-Entity Contracts assigned to this child}
   Slice scope: {this child's row from parent ### Entity Decomposition}
   ```

4. Use inherited decisions throughout sharp: in Musk Audit Q2 (fastest path respects ADRs), in User Journey (journey must implement assigned contracts), in Size Assessment (shared research reduces research scope).

**Why:** Epic architecture decisions are not negotiable per-child — children inherit them. Reading parent context before sharp prevents contradictory implementations across child entities.

## Runtime Detection Preamble

Before running codebase probes in Step 3.1, detect the project stack so probe commands reference the correct runner:

### Step R1: Detect Stacks

```bash
detected_stacks=()
ls bun.lock bun.lockb 2>/dev/null && detected_stacks+=("bun")
ls pnpm-lock.yaml 2>/dev/null && detected_stacks+=("pnpm")
ls yarn.lock 2>/dev/null && detected_stacks+=("yarn")
ls package-lock.json 2>/dev/null && detected_stacks+=("npm")
ls Cargo.toml 2>/dev/null && detected_stacks+=("cargo")
ls go.mod 2>/dev/null && detected_stacks+=("go")
ls pyproject.toml requirements.txt Pipfile 2>/dev/null | head -1 | grep -q . && detected_stacks+=("python")
ls Gemfile 2>/dev/null && detected_stacks+=("ruby")
ls mix.exs 2>/dev/null && detected_stacks+=("elixir")
ls build.gradle build.gradle.kts pom.xml 2>/dev/null | head -1 | grep -q . && detected_stacks+=("jvm")
ls Makefile GNUmakefile makefile 2>/dev/null | head -1 | grep -q . && detected_stacks+=("make")
ls pubspec.yaml 2>/dev/null && detected_stacks+=("dart")
echo "detected_stacks: ${detected_stacks[@]}"
```

### Step R2: Check README Frontmatter Override

Read `docs/{workflow}/README.md` for any `commands:` block that overrides detection.

### Step R3: Set {commands.test} for Probe Commands

Use the first detected stack (or README override) to set `{commands.test}`:

| Stack | {commands.test} |
|-------|----------------|
| bun | `bun test` |
| pnpm | `pnpm test` |
| yarn | `yarn test` |
| npm | `npm test` |
| cargo | `cargo test` |
| go | `go test ./...` |
| python | `pytest` |
| ruby | `bundle exec rspec` |
| elixir | `mix test` |
| jvm | `./gradlew test` or `mvn test` |
| make | `make test` |
| dart | `dart test` |

If multiple stacks detected: use `{commands.test}` from the primary stack (first detected) for size probe.
If `detected_stacks` is empty: use `{commands.test}` = `make test` as fallback, note "runner unknown — using make test as fallback".

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

### Step 2.8.5: Journey Code Trace (M/L only)

**Skip if**: all journey steps have Boundary = "—" (no cross-boundary steps to verify).

**Trigger**: Journey contains ≥ 2 steps with Boundary ≠ "—" → must run.

After the journey table is presented and captain confirms, **mechanically verify boundary-crossing steps against the actual codebase**. This is not conceptual — trace real code paths.

#### Classify each boundary-crossing step

| Classification | Description | Action |
|---|---|---|
| **MODIFY** | Step changes existing behavior (e.g., "middleware now requires auth") | Trace existing code path, verify assumptions match reality |
| **NEW** | Step requires code that doesn't exist yet (e.g., "POST /api/projects/register") | Skip trace — obviously NOT FOUND. Scan for hidden dependencies instead |

**MODIFY steps are high-value** — they catch "assumed A but reality is B" (e.g., "assumed share routes require auth, but they're actually public"). NEW steps returning NOT FOUND is noise.

#### Dispatch Explore agents by code layer (not journey number)

Organize by layer to avoid overlap:

```
Agent 1 — daemon/CLI layer (bin/daemon.ts, bin/cli.ts, src/):
  "Trace these MODIFY steps in the daemon/CLI layer: {list}.
   For each: entry file:line → boundary crossing → output file:line.
   Also: these NEW features will be added: {list}. 
   What existing daemon code will they need to integrate with?
   Hidden coupling points? Under 200 words per item."

Agent 2 — API/middleware layer (ui/app/api/, ui/middleware.ts):
  Same structure for API layer MODIFY + NEW items.

Agent 3 — UI component layer (ui/components/, ui/app/):
  Same structure for UI layer MODIFY + NEW items.
```

Wait for **all agents to complete** before compiling the trace table. Do NOT pre-fill from memory.

#### Compile Journey Code Trace table from agent results

```markdown
### Journey Code Trace

| Journey Step | Class | Boundary | Verdict | Evidence |
|---|---|---|---|---|
| 3. POST /api/comments → 201 | MODIFY | frontend → API | ✅ | route.ts:12 handles POST, writes to DB |
| 5. Middleware requires auth | MODIFY | middleware → Supabase | ❌ OPPOSITE | share routes are PUBLIC (middleware.ts:82), not auth-gated |
| 7. Claude receives notification | MODIFY | PG → daemon → CC | ⚠️ PARTIAL | CloudClient exists (cloud-client.ts:43) but pending route data source unclear |
| 9. New registration API | NEW | daemon → API → PG | — SCAN | No hidden coupling found; daemon already has apiFetch helper |
```

Verdicts:
- ✅ — code path confirmed, matches journey assumption
- ❌ — code path exists but **behaves opposite to assumption** (highest value finding)
- ⚠️ PARTIAL — code path exists but with caveats or unclear behavior
- — SCAN — new code; hidden dependency scan only (no trace needed)

#### Present to captain

**If all ✅ or — SCAN:**
> Journey code trace: all {N} boundary crossings verified. Proceeding.

**If any ❌ or ⚠️:**
> Journey code trace found {N} issue(s):
> - Step {X}: {what's broken/opposite and why}
>
> Options: (a) add fix to scope, (b) note as known gap + defer, (c) revise journey

**Why this step exists:** Journey steps are design-level assertions ("data flows from A to B"). Without code tracing, broken paths survive into plan/execute where they cost 10x more to discover. Dogfood learnings from acl-sharing sharp (#039): (1) MODIFY traces caught "share routes are PUBLIC not private" — a reversed assumption that would have caused wrong middleware implementation. (2) NEW step traces returned obvious NOT FOUND — low value, replaced with dependency scan. (3) Organizing agents by code layer instead of journey number eliminated duplicate tracing of the same files.

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

## Step 3.5: Epic Mode — Decomposition (when size exceeds L)

**Trigger:** Size triage result = L AND captain confirms. After Step 3.3 captain confirmation, if size is L, ask:

> This directive is L-size — it may be too large for a single entity pipeline pass. Would you like to decompose it into an epic with vertical-slice child entities? (yes → epic mode / no → proceed as single L entity)

If captain says **no** → skip Step 3.5, proceed to Step 4 as normal L entity.

If captain says **yes** → enter epic mode:

### Epic Mode Step 1: Architecture Research

Dispatch two parallel research agents:

**Agent A — Architecture decisions:**
```
Agent(
  description: "Epic architecture research: {epic title}",
  model: sonnet,
  prompt: |
    Research architecture decisions for this epic directive: {problem statement}

    Identify:
    1. Auth/authorization strategy — what pattern to use across all children
    2. Data schema boundaries — which entities/tables are shared vs child-owned
    3. API contract boundaries — shared endpoints, response shapes, error formats
    4. Cross-cutting concerns — logging, error handling, feature flags that all children must respect

    For each decision, provide:
    - The decision (specific, actionable)
    - Rationale (why this choice)
    - Implication for children (what each child must do / must not do)
    - File:line citation if an existing pattern in the codebase applies

    Under 400 words total. No placeholders.
)
```

**Agent B — Decomposition proposal:**
```
Agent(
  description: "Epic decomposition proposal: {epic title}",
  model: sonnet,
  prompt: |
    Propose vertical slice decomposition for this directive: {problem statement}

    Core principle: each child entity must be a vertical E2E slice — an independently
    deliverable journey with a clear entry point, crossing all required layers (UI, API,
    storage), producing an observable outcome. Never split by layer (not "all API routes",
    not "all UI components", not "all models").

    Propose 3-5 child entities. For each child:
    - slug: {kebab-case}
    - vertical_slice: one sentence describing the full journey (entry → layers → outcome)
    - entry: what triggers this journey
    - exit: what observable outcome proves it shipped
    - depends_on: list of other child slugs this depends on (or empty)

    Output as a YAML list:
    ```yaml
    children:
      - slug: auth-registration
        vertical_slice: "Captain fills registration form → API creates user → DB persists → redirect to dashboard"
        entry: "GET /register page load"
        exit: "User record exists in DB, redirected to /dashboard"
        depends_on: []
      - slug: auth-login
        vertical_slice: "Captain submits credentials → API validates → session created → redirect"
        entry: "POST /api/auth/login"
        exit: "Session cookie set, redirected to /dashboard"
        depends_on: [auth-registration]
    ```

    Under 300 words total.
)
```

Wait for both agents to complete.

### Epic Mode Step 2: Present + Confirm Decomposition

Present findings to captain:

> **Architecture decisions:**
> {Agent A output — ADR bullets}
>
> **Proposed child entities:**
> {Agent B output — formatted as numbered list}
>
> Each child is a vertical E2E slice — entry point → all required layers → observable outcome.
> Horizontal splits (by layer) are rejected: no "all API routes" or "all UI components" children.
>
> Accept decomposition / Modify / Reject (proceed as single L entity)

If **modify** → iterate (max 2 rounds). Present updated decomposition.
If **reject** → exit epic mode, proceed to Step 4 as L entity.
If **accept** → proceed to Epic Mode Step 3.

### Epic Mode Step 3: Auto-Create Child Entity Files

For each confirmed child entity:

1. Create file at `{workflow_dir}/{child.slug}.md` with this exact frontmatter:
   ```yaml
   ---
   id: ""
   title: "{child.vertical_slice}"
   status: draft
   source: "epic decomposition of {epic_entity_slug} — {today_date}"
   started:
   completed:
   verdict:
   priority: {same as parent}
   score:
   worktree:
   parent: "{epic_entity_id}"
   depends-on: [{child.depends_on as quoted list, or []}]
   tracker:
   issue:
   external_id:
   pr:
   token_budget:
   token_actual:
   ---

   Child entity of epic `{epic_entity_slug}`. Vertical slice: {child.vertical_slice}

   Entry: {child.entry}
   Exit (observable outcome): {child.exit}
   ```

2. Assign ID via:
   ```bash
   python3 {spacedock_plugin_dir}/skills/commission/bin/status --workflow-dir {workflow_dir} --next-id
   ```
   Write returned ID into child frontmatter `id:` field. Repeat for each child (IDs must be unique).

3. After all children created, update the epic entity frontmatter:
   ```yaml
   entity_type: epic
   children: [{child.slug1}, {child.slug2}, ...]
   ```

4. Commit:
   ```
   epic: decompose {epic_slug} → [{child1}, {child2}, ...]
   ```

### Epic Mode Step 4: Write ## Epic Context to Epic Entity

Append to the epic entity body (after `## Sharp Output`):

```markdown
## Epic Context

### Architecture Decisions
{From Agent A output — formatted as: "- **{decision}**: {rationale} — {implication for children}"}

### Cross-Entity Contracts
{List of shared API contracts, data schemas, interface boundaries derived from Agent A output}
- **{contract name}**: {definition} — implemented by {child-slug(s)}

### Entity Decomposition

| Child | Vertical Slice | Entry | Exit | Depends On |
|-------|---------------|-------|------|------------|
{One row per confirmed child entity}

### Shared Research
{Key codebase findings from epic-level research that children should reference to avoid duplicate work}
- {finding with file:line citation}
```

### Epic Mode Step 5: Set Status and Exit

1. Write `status: epic` to the epic entity frontmatter.
2. Write `## Sharp Report` with `status: passed, path: epic-decomposition`.
3. Report to captain:

   > Epic created. {n} child entities in draft:
   > {list of child slugs with titles}
   >
   > Epic entity is frozen at `status: epic` — FO will skip it in `--next` output.
   > Children flow through the pipeline independently.
   > Each child's sharp stage will inherit Architecture Decisions and Cross-Entity Contracts.

4. **EXIT ship-sharp.** Do not continue to Step 4. The epic entity does not flow through plan/execute/verify/ship.

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

**Skip silently** if ALL of these are true:
- Entity frontmatter `issue` field is empty or absent
- Entity frontmatter `tracker` field is empty or absent
- Directive text does not contain issue patterns (`#NNN`, `owner/repo#NNN`, `PROJ-NNN`)

If any issue info exists → proceed:
- Detect provider from format: `#42` or `owner/repo#42` → `tracker: gh`. `PROJ-123` pattern → `tracker: linear`.
- Write `tracker`, `issue`, and `external_id` to frontmatter.
- If `tracker: linear` and Linear MCP is available, verify the issue exists via `mcp__claude_ai_Linear__get_issue`.
- If no issue info detected anywhere → leave `tracker`, `issue`, `external_id` fields empty and proceed silently. Do NOT ask captain.

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

**Section tagging (mandatory):** Wrap each H2/H3 section you write with its HTML comment tag pair. Tag names come from `references/entity-body-schema.yaml` → `section_tag` field. Nest inner tags within outer tags. Example:

```markdown
<!-- section:sharp-output -->
## Sharp Output

<!-- section:problem -->
### Problem
{content}
<!-- /section:problem -->

<!-- section:done-criteria -->
### Done Criteria
{content}
<!-- /section:done-criteria -->

<!-- /section:sharp-output -->
<!-- section:sharp-report -->
## Sharp Report
{fields}
<!-- /section:sharp-report -->
```

Full tag list for this skill (from schema section_tag values):
- `## Sharp Output` → `sharp-output` (layer: decision)
- `### Shape Output` → `shape-output` (layer: decision)
- `### Roadmap Position` → `roadmap-position` (layer: decision)
- `### Problem` → `problem` (layer: decision)
- `### Done Criteria` → `done-criteria` (layer: decision)
- `### User Journey` → `user-journey` (layer: decision)
- `### Journey → DC Mapping` → `journey-dc-mapping` (layer: decision)
- `### Size Assessment` → `size-assessment` (layer: decision)
- `### Musk Audit` → `musk-audit` (layer: decision)
- `### Scoring Gate` → `scoring-gate` (layer: decision)
- `### Project Skills` → `project-skills` (layer: decision)
- `## Sharp Report` → `sharp-report` (layer: implementation)

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
started_at: "{ISO 8601 timestamp}"
completed_at: "{ISO 8601 timestamp}"
duration_minutes: {number}
```

FO reads `status:` and `stage_cost:` lines for dispatch decisions and `token_actual` accumulation. Calculate duration from the recorded start timestamp to now. Write started_at, completed_at, and duration_minutes to the report.

## Circuit Breakers

- If captain can't answer Question 1 (what problem?) after 2 attempts → suggest the entity isn't ready. Move back to draft.
- Shape phase: if captain rejects all 3 problem statements and can't articulate what they want → "This directive needs more thinking. Save as draft and revisit."
- Decomposition: if shape reveals N distinct features → emit "decomposition recommended — directive spans N features. Split into N entities and sharp each."

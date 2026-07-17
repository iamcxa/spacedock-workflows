---
name: ship-onboard
description: "Use when adopting ship-flow in a repo after workflow scaffolding exists, or when onboarding needs initial PRODUCT and ROADMAP context."
user-invocable: true
argument-hint: ""
---

# Ship-Onboard — Bootstrap Project Context

You are running the ONBOARD skill for ship-flow. This runs once when ship-flow is adopted in a new repo. Your job: scan the codebase, generate PRODUCT.md and ROADMAP.md drafts, then ask the captain to confirm.

**This skill is captain-interactive.** You ask questions, present drafts, iterate until captain approves.

---

## Pre-Check

0. Detect mode: Check if captain invoked with a PRS fragment argument:
   - If captain provided a PRS fragment (product requirements specification — a structured list of functional requirements, user stories, or feature bullets describing an existing or planned product area): → enter **midway mode** (proceed to Midway Mode section below).
   - If no PRS provided: → enter **greenfield mode** (proceed to Step 1: Codebase Scan).

0.5. Detect workflow scaffolding (greenfield mode only):
   ```bash
   find . -maxdepth 3 -name "README.md" \
     -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" \
     -exec grep -l "commissioned-by:" {} \; 2>/dev/null
   ```
   - If `docs/<wf>/README.md` with `commissioned-by:` frontmatter found → workflow scaffolding exists. Skip the prerequisite suggestion below; proceed to step 1 (PRODUCT.md / ROADMAP.md check). Ship-onboard focuses only on PRODUCT/ROADMAP **content** drafting, not workflow structure.
   - If NO `commissioned-by:` README found → workflow scaffolding missing. Continue to step 0.6.

0.6. Suggest workflow-adopt prerequisite (greenfield mode only — skip if step 0.5 found scaffolding):

   > **No workflow scaffolding detected.**
   >
   > ship-onboard drafts PRODUCT.md and ROADMAP.md (project **content**) but does not install workflow stages, gates, or skill bindings (project **structure**).
   >
   > **Adoption note (0.7.0):** Bootstrapping ship-flow workflow scaffolding is **not self-contained in 0.7.0**. The recommended bridge is `/spacebridge:workflow-adopt`, which discovers `workflow-template.yaml` and delegates to `spacedock:commission` — but this requires the `spacebridge` plugin. Without spacebridge, scaffold `docs/<wf>/` manually from `plugins/ship-flow/workflow-template.yaml` or run `/spacedock:commission` with ship-flow directly. Self-contained adoption is a planned later milestone.
   >
   > How to proceed?
   >   **y** — continue now: PRODUCT.md and ROADMAP.md land at repo root; wire them into workflow scaffolding later (manual or via spacebridge when available)
   >   **spacebridge** — pause here and run `/spacebridge:workflow-adopt` first (if spacebridge plugin is installed), then re-run this skill
   >   **n / abort** — stop for now

   Wait for captain answer. On `y`: continue to step 1. On `spacebridge`, `n`, or `abort`: emit the following note and stop (do NOT hard-error — the adopter may lack spacebridge, which is expected in 0.7.0):
   > Stopping ship-onboard. To bootstrap workflow scaffolding: run `/spacebridge:workflow-adopt` (requires spacebridge plugin) or scaffold `docs/<wf>/` manually from `plugins/ship-flow/workflow-template.yaml`. Then re-invoke `/ship-flow:ship-onboard`.

1. Check if PRODUCT.md or ROADMAP.md already exist at project root:
   ```bash
   ls PRODUCT.md ROADMAP.md 2>/dev/null
   ```
2. If both exist → ask captain: "PRODUCT.md and ROADMAP.md already exist. Overwrite, merge, or skip?"
3. If one exists → generate only the missing one.
4. If neither exists → proceed with full generation.

---

## Midway Mode — Retroactive Epic Creation for Existing Projects

> Use when a project is partially complete and the captain provides a PRS fragment to retroactively classify what's done, what's partial, and what remains.

Jump to **Midway Step 1** below. Skip Step 1-6 (greenfield flow).

---

## Step 1: Codebase Scan

Run these probes to understand the project:

### 1.1: Structure
```bash
# Top-level structure
ls -la
# Source tree depth
find src/ lib/ plugins/ app/ 2>/dev/null -type f | head -50
# Package info
cat package.json 2>/dev/null | head -30
# Tech stack indicators
ls tsconfig.json pyproject.toml go.mod Cargo.toml Dockerfile docker-compose.yml 2>/dev/null
```

### 1.2: Scale
```bash
# File counts by type
find . -type f -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.go" | grep -v node_modules | wc -l
# Test coverage indicator
find . -type f -name "*.test.*" -o -name "*.spec.*" | grep -v node_modules | wc -l
# Module count
find src/ lib/ plugins/ 2>/dev/null -maxdepth 1 -type d | wc -l
```

### 1.3: Activity
```bash
# Recent commit patterns
git log --oneline -20
# Contributors
git shortlog -sn --since="3 months ago" | head -10
# Active areas
git log --since="30 days ago" --name-only --pretty=format: | sort | uniq -c | sort -rn | head -15
```

### 1.4: Existing Documentation
```bash
# README
head -50 README.md 2>/dev/null
# Any existing architecture docs
find . -name "ARCHITECTURE.md" -o -name "CONTRIBUTING.md" -o -name "DESIGN.md" -o -name "CLAUDE.md" 2>/dev/null
```

### 1.5: Dependencies
```bash
# Key dependencies (not devDeps)
cat package.json 2>/dev/null | grep -A 50 '"dependencies"' | head -30
# Or for Python
cat pyproject.toml 2>/dev/null | grep -A 30 'dependencies'
```

### 1.6: Adopter Skill Routing Discovery

Run the adopter skill discovery helper after the baseline codebase scan:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/discover-adopter-skills.sh" --root=.
```

If the output contains one or more `routing:` entries, present the discovered
`.claude/ship-flow/skill-routing.yaml` draft to the captain before writing it.
This file is adopter-specific: it captures file-signal skills such as
`refine-expert`, `expo-rnr-nativewind`, `ts-rest`, or project DB helpers that
do not belong in plugin defaults.

Keep `.claude/ship-flow/domains.yaml` separate. Domain registry
`required_skills` stay there; file-signal skills live in
`.claude/ship-flow/skill-routing.yaml`.

### 1.7: Contribution Contract Bundle

When the adopter uses `.claude/ship-flow/doc-coupling.yaml`, install the canonical self-contained checker beside it:

```bash
mkdir -p .claude/ship-flow
cp "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/bin/doc-impact-gate.sh" \
  .claude/ship-flow/doc-impact-gate.sh
chmod +x .claude/ship-flow/doc-impact-gate.sh
mkdir -p .github/workflows
cp "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/references/ship-flow-doc-impact-workflow.yml" \
  .github/workflows/ship-flow-doc-impact.yml
```

Record the map, checker, and workflow in version control. Verify the adopted checker without relying on a vendored plugin tree:

```bash
bash .claude/ship-flow/doc-impact-gate.sh --help
```

On every Ship Flow upgrade, compare and re-copy both the canonical checker and workflow before accepting a map-schema change. A map without its adopted checker or workflow caller is a blocking incomplete adoption; CI must not fetch or inline a second implementation.

---

## Step 2: Generate PRODUCT.md Draft

Based on scan results, generate a draft following this structure:

```markdown
# {Project Name}

> {One-sentence description derived from package.json description or README first line}

## Vision

{2-3 sentences about what this project is becoming. Derive from README, recent commit patterns, and architecture. Be honest — if vision is unclear from the code, say "Vision to be defined by captain."}

## Who It Serves

| Persona | Description | Primary need |
|---------|-------------|-------------|
| {role 1} | {who they are} | {what they need from this project} |
| {role 2} | ... | ... |

{Derive personas from: README mentions of users/roles, CLI help text, API route naming patterns, UI page structure. Default: "Developer" if unclear.}

## Current Capabilities

{Group by domain. Each bullet follows doc-format.md capability format.}

### {Domain 1}
- {What it does} — {why it matters}
- ...

### {Domain 2}
- ...

{Derive from: source tree structure, exported functions/routes/pages, test descriptions, README feature lists.}

## Architecture

{2-3 sentences about how the project is structured. Mention: primary language, framework, key directories, data flow.}

### Key Directories
| Directory | Purpose |
|-----------|---------|
| `src/` | {derived from file contents} |
| ... | ... |

## Constraints

| Constraint | Reason |
|-----------|--------|
| {technical or business constraint} | {why it exists} |

{Derive from: tsconfig strict mode, lint rules, CLAUDE.md rules, Dockerfile base image, CI config.}

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | {from scan} |
| Framework | {from dependencies} |
| Testing | {from devDeps} |
| Build | {from scripts} |
```

---

## Step 3: Generate ROADMAP.md Draft

```markdown
# {Project Name} — Roadmap

> North Star: {same as PRODUCT.md Vision, condensed to one sentence}

## Now

| Slug | Size | Why now |
|------|------|---------|
{Empty — captain fills this during first /ship-shape}

## Next

| Idea | Why next | Estimated size |
|------|----------|---------------|
| {derived from TODOs, open issues, recent PR patterns} | {reasoning} | {S/M/L} |

## Later

| Idea | Why later |
|------|----------|
| {derived from README "future plans", FIXME comments, deferred PRs} | {reasoning} |

## Not Doing

| Idea | Why not |
|------|--------|
{Empty — captain fills this when rejecting entities at sharp}

## Shipped

| # | Feature | Why it existed | Date | Outcome |
|---|---------|---------------|------|---------|
{Empty — ship-review populates this}

## Cost Calibration

| Size | Budget | Sample | Median actual |
|------|--------|--------|--------------|
| S | $2-5 | 0 | — |
| M | $8-15 | 0 | — |
| L | $30-50 | 0 | — |

{Calibration table populated automatically as entities ship. Sample and Median update after each shipped entity.}
```

---

## Step 4: Populate Next/Later from Codebase Signals

Scan for forward-looking signals to populate ROADMAP.md Next/Later:

```bash
# TODOs and FIXMEs
grep -rn "TODO\|FIXME\|HACK\|XXX" src/ lib/ plugins/ 2>/dev/null | grep -v node_modules | head -20

# Open GitHub issues (if gh available)
gh issue list --limit 10 --state open 2>/dev/null

# Recent feature branches not merged
git branch -r --no-merged main 2>/dev/null | head -10
```

Classify each signal:
- Active TODO with recent git blame → **Next** (someone was thinking about it recently)
- Old TODO with no recent activity → **Later**
- Open GitHub issue → **Next** (with issue ref)
- Stale branch → **Later** (may be abandoned)

---

## Step 5: Captain Review

Present both drafts to captain. Ask sequentially:

### 5.1: PRODUCT.md Review
> Here's the PRODUCT.md draft based on codebase scan:
>
> {show full draft}
>
> **Review checklist:**
> 1. Is the Vision accurate? (This is the North Star — gets copied to ROADMAP.md)
> 2. Are the Personas right? (Who actually uses this?)
> 3. Any capabilities missing or wrong?
> 4. Any constraints missing?
>
> Edit, approve, or tell me what to change.

Iterate until captain approves.

### 5.2: ROADMAP.md Review
> Here's the ROADMAP.md draft:
>
> {show full draft}
>
> **Review checklist:**
> 1. Is the North Star the same as PRODUCT.md Vision? (Must be identical)
> 2. Any items in Next that should be Now (urgent)?
> 3. Any items that should be Not Doing?
> 4. Anything missing from Later?
>
> Edit, approve, or tell me what to change.

Iterate until captain approves.

---

## Step 6: Write Files

After captain approves both:

1. Write PRODUCT.md to project root
2. Write ROADMAP.md to project root
3. Commit:
   ```bash
   git add -- PRODUCT.md ROADMAP.md
   git commit -m "docs: bootstrap PRODUCT.md + ROADMAP.md via ship-onboard" -- PRODUCT.md ROADMAP.md
   ```

   > **Commit discipline**: every `git add` + `git commit` in this skill uses pathspec-lock (`-- <paths>`) syntax at BOTH stage-time and commit-time. Forbidden staging patterns (`git add -A`, `git add .`, `git commit -am`, `git commit -a -m`) are documented in `plugins/ship-flow/skills/ship-execute/SKILL.md` → "Forbidden staging patterns" section. See also MEMORY #31 (parallel-session git staging contamination) and entity #063.

4. Confirm:
   > **Onboard complete.** PRODUCT.md and ROADMAP.md created.
   > Run `/ship-shape` to start your first entity.

---

## Circuit Breakers

- If codebase scan finds 0 source files → warn captain: "This looks like an empty repo. Create PRODUCT.md and ROADMAP.md manually."
- If README.md is missing → generate PRODUCT.md with more "to be defined" sections and warn captain.
- Captain review: max 3 iterations per document. After 3 → write what captain last approved and note remaining concerns as comments in the file.
- If `gh` CLI is not available → skip GitHub issue scan, note in ROADMAP.md: "GitHub issues not scanned — gh CLI not authenticated."

---

## Midway Step 1: Parse PRS Fragment

Analyze the PRS fragment the captain provided. Extract all functional requirements, user stories, and feature bullets. Group them by functional domain.

**How to group by domain:**
- Look for recurring nouns/objects (membership, voucher, payment, notification, messaging, auth...)
- Group items that share a data model or user journey
- Aim for 2-5 domains; merge very small domains (1-2 items) into a related domain
- Name each domain clearly: `{project}-{domain}` (e.g., `carlove-membership`, `carlove-vouchers`)

**Output format** — present to captain before proceeding:

> **PRS Parsing Result:**
>
> Domain: `{domain-name-1}` ({N} items)
> - {item 1}
> - {item 2}
> ...
>
> Domain: `{domain-name-2}` ({N} items)
> - ...
>
> **{Total N} PRS items across {D} domains.**
>
> Proceeding to codebase exploration. (If you want to adjust domain groupings, say so now.)

Wait for captain acknowledgement or adjustment. If captain adjusts → re-group and confirm again.

Record the final domain list as `{domain_list}` for use in Midway Step 2.

## Midway Step 2: Dispatch Named Teammate Agents

For each domain in `{domain_list}`, dispatch a named persistent teammate to explore the codebase. Run all teammates in parallel (one Agent per domain).

**Agent dispatch template** (repeat for each domain):

```
Agent(
  name: "{project}-{domain}-explorer",
  description: "Codebase explorer for {domain} domain — persistent for follow-up questions",
  model: sonnet,
  prompt: |
    You are the {domain} domain explorer for the {project} codebase.

    ## Your Mission
    Explore the codebase for evidence of these PRS items:

    {list each PRS item in this domain, numbered}

    ## Codebase Access
    Project root: {project_root}
    Scan these directories first: src/, lib/, plugins/, app/, {any domain-specific dirs you discover}

    ## Classification Rules
    For each PRS item, report one of:
    - **done** — fully implemented with file:line evidence. Test coverage exists (if testable).
    - **partial** — code exists but incomplete (missing edge cases, no tests, TODO comments, disabled feature flag, scaffolding only). Cite what exists AND what's missing.
    - **not-started** — no implementation found. Search with at least 3 different grep terms before concluding not-started.

    ## Exploration Strategy
    1. Grep for domain-specific terms (entity names, function names, route paths)
    2. Read top-level files in domain directories
    3. Check test files — test coverage = strong evidence of "done"
    4. Check for TODO/FIXME comments on partial items

    ## Output Format
    For each PRS item:
    ```
    Item N: {item text}
    Status: done | partial | not-started
    Evidence: {file:line citation} — {what was found}
    Missing (if partial): {what's absent}
    ```

    Report all {N} items. Do not skip any.
)
```

**Progressive follow-up via SendMessage:**

After initial teammate reports arrive, ask follow-up questions without re-dispatching new agents. Use SendMessage to the existing named agent:

```
SendMessage(
  to: "{project}-{domain}-explorer",
  message: "Follow-up: {specific question}. For example: Is the {endpoint} route tested? Does the {feature} handle {edge case}? Check {specific file} for {specific pattern}."
)
```

**When to send follow-ups:**
- A "partial" item lacks clarity on what's missing → ask specifically
- A "done" item has no test evidence → ask the teammate to check test files
- An item was marked "not-started" but you suspect scaffolding exists → ask to check for stub/TODO patterns

**Aggregate results:**

After all teammates report (and follow-ups are resolved), build the classification table:

| # | PRS Item | Domain | Status | Evidence |
|---|----------|--------|--------|----------|
| 1 | {item text} | {domain} | done / partial / not-started | {file:line} |
| ... | ... | ... | ... | ... |

Keep this table as `{classification_table}` for use in Midway Steps 3-5.

**Circuit breaker:** If a teammate fails to respond within 2 minutes → mark all its items as "not-started (exploration failed)" and proceed. Do not retry the same agent.

## Midway Step 3: Classification Review

Before creating any entity files, present the full classification table to the captain for review.

> **Classification ready for review.**
>
> Here's what the codebase analysis found:
>
> {display {classification_table} formatted as markdown table}
>
> **Summary:**
> - Done: {N} items across {D} domains
> - Partial: {N} items
> - Not started: {N} items
>
> **Entity plan:**
> - 1 epic entity: `{project}-epic`
> - {N_done_domains} done child entities (status: done, no further pipeline work)
> - {N_draft_domains} draft child entities (status: draft, will flow through sharp → execute normally)
>
> **Before I write the files:**
> 1. Are the classifications correct? (Change any status by saying "Item 3 should be partial, not done — missing {reason}")
> 2. Should any domains be merged or split?
> 3. Any items to exclude from epic scope?
>
> Reply **"confirmed"** to proceed, or describe adjustments.

**Adjustment handling:**
- If captain changes a status → update `{classification_table}` and re-present the summary (not the full table again, just the delta)
- Max 2 adjustment rounds before writing. After 2 rounds → write what captain last confirmed and note remaining concerns in the epic entity `## Classification Evidence` section.

After captain confirms → proceed to Midway Step 4 (entity creation).

## Midway Step 4: Create Epic + Child Entities

Using `{classification_table}` from Midway Step 2 (after captain confirmed in Step 3), create the epic entity and all child entities.

### 4.1: Create Epic Entity

Create a new entity file at `docs/{workflow}/ship-onboard-{project}-epic.md` (or captain-specified path) with:

```yaml
---
id: "{next available id}"
title: "{project name} — {PRS section title} epic"
status: epic
entity_type: epic
children: ["{child-slug-1}", "{child-slug-2}", ...]
source: "ship-onboard midway mode"
started: {today ISO 8601}
completed:
verdict:
priority: P1
score:
worktree:
parent:
depends-on: []
tracker:
issue:
external_id:
pr:
token_budget:
token_actual:
---
```

**Section tagging (mandatory):** Wrap the Epic Context and each subsection with their tags:

```markdown
<!-- section:epic-context -->
## Epic Context

<!-- section:architecture-decisions -->
### Architecture Decisions
{content}
<!-- /section:architecture-decisions -->

<!-- section:cross-entity-contracts -->
### Cross-Entity Contracts
{content}
<!-- /section:cross-entity-contracts -->

<!-- section:entity-decomposition -->
### Entity Decomposition
{table}
<!-- /section:entity-decomposition -->

<!-- section:shared-research -->
### Shared Research
{content}
<!-- /section:shared-research -->

<!-- /section:epic-context -->
```

Tag list: `epic-context` (decision), `architecture-decisions` (decision), `cross-entity-contracts` (decision), `entity-decomposition` (decision), `shared-research` (decision)

Then write `## Epic Context` to the epic entity body:

```markdown
## Epic Context

### Architecture Decisions

{Synthesize from teammate reports: key patterns found in the codebase — auth strategy, data model boundaries, API conventions. If no architecture patterns were found, write "No established patterns found — children should propose."}

### Cross-Entity Contracts

{Shared data models, shared API routes, shared types referenced across multiple PRS items. Format: "- **{contract name}**: {what it defines} — shared across {domain1}, {domain2}"}

### Entity Decomposition

| Child | Vertical Slice | Entry | Exit | Depends On |
|-------|---------------|-------|------|-----------|
{one row per domain from {domain_list}: child = "{project}-{domain}", Vertical Slice = description of the PRS items in that domain, Entry = how user/system starts, Exit = observable outcome}

### Shared Research

{Key codebase findings that all children should know: framework version, project conventions, test patterns, directory structure. From teammate reports.}
```

### 4.2: Create Child Entities

For each domain, create a child entity file at `docs/{workflow}/{project}-{domain}.md`:

**For domains where ALL items are "done":**
```yaml
---
id: "{next id}"
title: "{project} {domain} — {brief scope description}"
status: done
entity_type: entity
parent: "{epic-entity-id}"
...
---
```
Body: write `## Sharp Output` with `### Problem` derived from PRS items, `### Done Criteria` from the PRS items (all pre-checked), `### Size Assessment: S` (already done). Add `## Classification Evidence` citing the teammate file:line evidence.

**For domains with any "partial" or "not-started" items:**
```yaml
---
id: "{next id}"
title: "{project} {domain} — {brief scope description}"
status: draft
entity_type: entity
parent: "{epic-entity-id}"
...
---
```
Body: write minimal `## Sharp Output` stub with `### Problem` and `### Done Criteria` (items not yet done). Leave `status: draft` for FO to dispatch to sharp normally.

### 4.3: Commit all created files

```bash
git add -- docs/{workflow}/
git commit -m "feat: ship-onboard midway mode — {project} epic + {N} child entities" -- docs/{workflow}/
```

## Midway Step 5: Update ROADMAP.md and PRODUCT.md

Update ROADMAP.md and PRODUCT.md to reflect the classified done items.

### 5.1: Update ROADMAP.md

Read ROADMAP.md from project root. If it exists:

1. Find or create `## Shipped` table.
2. For each PRS item classified as "done", append a row:
   ```
   | {epic-entity-id} | {PRS item description} | {one-sentence from PRS context, present tense} | {today's date} | ⏳ |
   ```
   Note: retroactive items are pre-verified by codebase evidence. Skip verify pre-check.
3. For each draft child entity, add a row to `## Now` table (it needs pipeline work):
   ```
   | {child-slug} | {size estimate S/M} | {reason: partial/not-started items from PRS} |
   ```

If ROADMAP.md doesn't exist → skip (no error).

### 5.2: Update PRODUCT.md

Read PRODUCT.md from project root. If it exists:

For each domain with all items done, add a capability bullet to the matching domain section in `## Current Capabilities`:
```
- {Domain capability description — what it does} — {why it matters} (#{epic-entity-id})
```

Match the domain name to an existing subsection if possible. If no matching subsection → create one.

If PRODUCT.md doesn't exist → skip (no error).

### 5.3: Commit doc updates

```bash
git add -- ROADMAP.md PRODUCT.md
git commit -m "docs: ship-onboard midway — update ROADMAP + PRODUCT for {project} ({N} done items)" -- ROADMAP.md PRODUCT.md
```

### 5.4: Confirm to captain

> **Midway onboard complete.**
>
> Created:
> - 1 epic entity: `{epic-entity-id}`
> - {N} done child entities
> - {N} draft child entities (ready for `/ship-shape`)
> - ROADMAP.md updated ({N} shipped, {N} added to Now)
> - PRODUCT.md updated ({N} capability bullets added)
>
> FO can now dispatch draft children through the pipeline with `--next`.

## Midway Circuit Breakers

- **PRS parsing yields 0 domains** → warn captain: "Could not group PRS items into domains. Paste a more structured PRS fragment or manually group items and re-invoke."
- **Teammate exploration fails** (agent timeout / error) → mark all items for that domain as "not-started (exploration failed)". Include in classification table with note. Proceed.
- **Captain adjustment loop > 2 rounds** → write what captain last confirmed. Note remaining concerns in epic entity `## Classification Evidence`.
- **PRODUCT.md/ROADMAP.md missing** → skip update step (no error). Note in confirmation: "PRODUCT.md/ROADMAP.md not found — skipped doc updates."
- **Duplicate epic** (captain re-runs midway mode for same project) → detect by checking if an entity with `entity_type: epic` and `source: "ship-onboard midway mode"` already exists for this project. If found → ask captain: "An existing epic for {project} was found at {path}. Continue (will add children to existing epic) or start fresh?"

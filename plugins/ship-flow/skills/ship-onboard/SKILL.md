---
name: ship-onboard
description: "Use when adopting ship-flow in a new repo. Scans codebase to generate initial PRODUCT.md + ROADMAP.md drafts for captain confirmation. Run once per repo."
user-invocable: true
argument-hint: ""
---

# Ship-Onboard — Bootstrap Project Context

You are running the ONBOARD skill for ship-flow. This runs once when ship-flow is adopted in a new repo. Your job: scan the codebase, generate PRODUCT.md and ROADMAP.md drafts, then ask the captain to confirm.

**This skill is captain-interactive.** You ask questions, present drafts, iterate until captain approves.

---

## Pre-Check

1. Check if PRODUCT.md or ROADMAP.md already exist at project root:
   ```bash
   ls PRODUCT.md ROADMAP.md 2>/dev/null
   ```
2. If both exist → ask captain: "PRODUCT.md and ROADMAP.md already exist. Overwrite, merge, or skip?"
3. If one exists → generate only the missing one.
4. If neither exists → proceed with full generation.

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
{Empty — captain fills this during first /ship-sharp}

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
   git add PRODUCT.md ROADMAP.md
   git commit -m "docs: bootstrap PRODUCT.md + ROADMAP.md via ship-onboard"
   ```
4. Confirm:
   > **Onboard complete.** PRODUCT.md and ROADMAP.md created.
   > Run `/ship-sharp` to start your first entity.

---

## Circuit Breakers

- If codebase scan finds 0 source files → warn captain: "This looks like an empty repo. Create PRODUCT.md and ROADMAP.md manually."
- If README.md is missing → generate PRODUCT.md with more "to be defined" sections and warn captain.
- Captain review: max 3 iterations per document. After 3 → write what captain last approved and note remaining concerns as comments in the file.
- If `gh` CLI is not available → skip GitHub issue scan, note in ROADMAP.md: "GitHub issues not scanned — gh CLI not authenticated."

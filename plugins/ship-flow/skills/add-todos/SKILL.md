---
name: add-todos
description: "Low-friction todo capture for ship-flow. Parses free text (single idea or semicolon/newline/bullet-separated list) into todo files + ROADMAP.later rows in one atomic commit. Use when captain has a quick idea or rabbit hole to file without starting a full shape cycle."
user-invocable: true
argument-hint: "\"<idea text>\" | \"idea 1; idea 2; idea 3\""
---

# Add-Todos — Low-Friction Idea Capture

You are running the ADD-TODOS skill. Your job is to classify and file one or more ideas as `docs/ship-flow/todos/<slug>.md` files and append matching rows to ROADMAP.md `later` section — all in a single atomic commit.

**Core contract:** minimal friction. No shaping, no questions. Parse → classify → file → commit. Report slugs filed.

## Stage-wide capture rule

Use this skill for every out-of-scope finding discovered during
plan/design/execute/verify/review/ship when the issue is worth preserving but
does not directly belong to the active entity's acceptance criteria or fix loop.
This includes pre-existing bugs, genuinely new feature requests, research
rabbit holes, workflow friction, and follow-up candidates discovered by workers,
reviewers, verifiers, external reviewers, or captain UAT.

Rejected alternatives are not todos. Keep rejected alternatives in the stage
artifact with the reason they were rejected; only capture follow-up candidates
that may become future work.

## Decision: todo vs sharp entity directly

This skill captures TODOS — items deferred to later. If the item warrants immediate sharp-entity creation (claiming `--next-id` and writing spec.md), use `/ship-flow:ship-shape <directive>` instead. Decision rule:

| Condition | Use |
|-----------|-----|
| Scope clear + design settled + **starting work now** | `/ship-flow:ship-shape` (skip todo, directly entity) |
| Scope clear + design settled + waiting on prerequisite | this skill (todo) |
| Scope fuzzy / multiple alternatives still considered | this skill (todo) |
| Depends on upstream entity outcome | this skill (todo) |
| Want to batch-process related ideas | this skill (todo) |

**Why**: entity creation immediately claims `--next-id` (MEMORY #5 atomic discipline). Don't lock IDs for work you're not about to execute — parallel sessions will be blocked or race. Todos are cheap capture + late binding via `/ship-flow:ship-shape <todo-tid>` when ready to start.

**Failure modes**: premature entity = empty placeholder folders littering `docs/<wf>/`; over-todo = backlog rot. Balance via the "starting now?" criterion above.

## Input parsing

The argument may contain multiple ideas. Split on:
- Semicolons (`;`)
- Newlines
- Numbered list markers (`1.`, `2.`, …)
- Bullet markers (`-`, `*`)

Trim whitespace from each segment. Discard empty segments. Each non-empty segment is one todo.

## Per-todo workflow

For each idea, execute these steps in sequence:

### Step 1 — Classify (haiku subagent, ~5s)

Dispatch a haiku subagent with prompt:

```
Classify this todo idea for a software project:
"<idea text>"

Return JSON only:
{
  "slug": "<kebab-case-slug-max-40-chars>",
  "domain": "<one of: backend | frontend | dashboard-ui | infra | dx | docs | unknown>",
  "guess_files": ["<path>", ...],
  "suggest_done_type": "<one of: code | ui | docs | infra | research>"
}
```

Use the returned `slug` for the file name. `guess_files` may be empty if domain is unclear.

### Step 2 — Deduplicate slug

Check if `docs/ship-flow/todos/<slug>.md` already exists. If yes, append `-2`, then `-3`, etc., until a free slot is found.

### Step 3 — Write todo file

Write `docs/ship-flow/todos/<slug>.md`:

```yaml
---
tid: <slug>
captured_at: <ISO-8601 UTC timestamp>
status: pending
domain: <from classification>
guess_files: [<from classification>]
suggest_done_type: <from classification>
entity: null
---

<original idea text, trimmed>
```

### Step 4 — Prepare ROADMAP.later row

Accumulate row: `| <slug> | S | <idea text, truncated to 60 chars> | (todo) |`

## After all todos are processed

### Step 5 — Batch patch ROADMAP.later

Use `plugins/ship-flow/lib/patch-map.sh` with `--mode=append --section=later --no-commit` to append all rows.

For each row:
1. Compute current hash: `sha256_of ROADMAP.md` (source `plugins/ship-flow/lib/map-helpers.sh`)
2. Pipe row via stdin to patch-map.sh with `--if-hash=<hash>`
3. If exit 6 (hash mismatch): abort with message "ROADMAP changed during write — retry /add-todos"

### Step 6 — Single atomic commit

```bash
git add -- docs/ship-flow/todos/<slug1>.md docs/ship-flow/todos/<slug2>.md ... ROADMAP.md
git commit -m "add-todos: <slug1>[, <slug2>...] ([N] new rabbit holes)" \
  -- docs/ship-flow/todos/<slug1>.md ... ROADMAP.md
```

**Explicit pathspec only** — never `git add -A` or `git commit -am`.

### Step 7 — Report

Output one line per todo filed:

```
Filed N todo(s):
  - <slug1>  [<domain>]  <guess_files or "(no files guessed)">
  - <slug2>  ...
Commit: <short SHA>
```

## Duplicate detection

If all slugs already existed (no new files written), exit without committing and report:
```
All ideas already exist as todos: <slug1>, <slug2>. Nothing committed.
```

## Error handling

| Condition | Action |
|-----------|--------|
| No argument provided | Print usage and exit |
| patch-map.sh missing or not executable | Exit with "Error: patch-map.sh not found at plugins/ship-flow/lib/patch-map.sh" |
| haiku classification fails | Use slug from first 40 chars of idea text (kebab-cased), domain=unknown, guess_files=[] |
| git commit blocked | Report "Files written but commit failed — check pre-commit hook" |

## Examples

**Single idea:**
```
captain: /add-todos "filter chip needs multi-select"
agent:   Filed 1 todo:
           - filter-chip-multi  [dashboard-ui]  ui/components/FilterChip.tsx
         Commit: a1b2c3d
```

**Multiple ideas (semicolon-separated):**
```
captain: /add-todos "add dark mode; fix pagination bug; document auth flow"
agent:   Filed 3 todo(s):
           - add-dark-mode        [frontend]       (no files guessed)
           - fix-pagination-bug   [backend]        src/api/pagination.ts
           - document-auth-flow   [docs]           docs/auth.md
         Commit: d4e5f6a
```

**Duplicate slug:**
```
captain: /add-todos "filter chip needs multi-select"
agent:   Filed 1 todo:
           - filter-chip-multi-2  [dashboard-ui]  ui/components/FilterChip.tsx
         Commit: b7c8d9e
         (filter-chip-multi already exists — used suffix -2)
```

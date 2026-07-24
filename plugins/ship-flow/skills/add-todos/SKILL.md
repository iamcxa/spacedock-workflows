---
name: add-todos
description: "Use when capturing ship-flow todo ideas, rabbit holes, or quick captain notes without starting a full shape cycle."
user-invocable: true
argument-hint: "\"<idea text>\" | \"idea 1; idea 2; idea 3\""
---

# Add-Todos — Low-Friction Idea Capture

You are running the ADD-TODOS skill. Your job is to classify and file one or more ideas as `{todos_root}/todos/<slug>.md` files (`{todos_root}` resolved once, below) and append matching rows to the repo-root `ROADMAP.md` `later` section — all in a single atomic commit on the code branch.

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

This skill captures TODOS — items deferred to later. If the item warrants immediate sharp-entity creation (claiming `--next-id` and writing `shape.md`), use `/ship-flow:ship-shape <directive>` instead. Decision rule:

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

## Resolve the workflow directory (once, before the loop)

Todos are code-branch artifacts. Do not assume a fixed workflow path — the workflow may sit elsewhere, and under split-root the entity checkout is a different branch. Resolve where they live:

1. **`{workflow_dir}`** — use `$WORKFLOW_DIR` when it is set (dispatched context). When unset — this skill is `user-invocable`, so a captain often runs it directly with no FO env — discover it: `${SPACEDOCK_BIN:-spacedock} status --discover` prints one workflow dir per line, scanning from the git repo root. Take the single result; if several, pick the ship-flow workflow (its README `entry-point:` names a `ship-flow:` skill); if none, abort with `no ship-flow workflow found — run /add-todos from inside a ship-flow repo`.
2. **`{todos_root}`** — run `${SPACEDOCK_BIN:-spacedock} status --boot --json --workflow-dir {workflow_dir}` and read `definition_dir`. Set `{todos_root} = definition_dir`. This is the code-branch directory that holds the README; todos and `ROADMAP.md` live here.

**Split-root note.** For a split-root workflow (its README declares `state:`), `_archive/` and `_debriefs/` live in the `.spacedock-state` entity checkout — but todos do **not**. A todo file is committed atomically with its repo-root `ROADMAP.md` row, and a single commit cannot span the code branch and the orphan state branch. So todos are definition-side: always `{definition_dir}/todos/`, always on the code branch — write them to `definition_dir`, never `entity_dir`.

Run all file writes and the commit from the repo root (`git rev-parse --show-toplevel`).

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

Check if `{todos_root}/todos/<slug>.md` already exists. If yes, append `-2`, then `-3`, etc., until a free slot is found.

### Step 3 — Write todo file

Write `{todos_root}/todos/<slug>.md`:

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

Use `${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/patch-map.sh` with `--mode=append --section=later --no-commit` to append all rows against the repo-root `ROADMAP.md`.

For each row:
1. Compute current hash: `sha256_of ROADMAP.md` (source `${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/map-helpers.sh`)
2. Pipe row via stdin to patch-map.sh with `--if-hash=<hash>`
3. If exit 6 (hash mismatch): abort with message "ROADMAP changed during write — retry /add-todos"

### Step 6 — Single atomic commit

```bash
# from the repo root; {todos_root} is the resolved definition_dir (code branch)
git add -- {todos_root}/todos/<slug1>.md {todos_root}/todos/<slug2>.md ... ROADMAP.md
git commit -m "add-todos: <slug1>[, <slug2>...] ([N] new rabbit holes)" \
  -- {todos_root}/todos/<slug1>.md ... ROADMAP.md
```

**Explicit pathspec only** — never `git add -A` or `git commit -am`. The todo files and `ROADMAP.md` are all on the code branch, so this stays a single atomic commit.

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
| patch-map.sh missing or not executable | Exit with "Error: patch-map.sh not found at ${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/patch-map.sh" |
| `status --discover` finds no ship-flow workflow | Exit with "no ship-flow workflow found — run /add-todos from inside a ship-flow repo" |
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

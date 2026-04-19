---
name: ship-capture
description: "Use when capturing a new ship-flow entity from an idea, observation, deferred work, bug report, or feature request. Zero-friction: free-form description → draft entity file in docs/ship-flow/ with sensible defaults. Triggers on '/ship-flow:ship-capture <text>', 'capture this as ship-flow', 'create ship-flow entity', '建立 ship-flow entity', '記下這個', '記成 entity', 'add to ship-flow backlog'."
user-invocable: true
argument-hint: "<description> [--priority P0|P1|P2|P3] [--epic] [--parent <id>] [--depends-on id1,id2] [--source 'context']"
---

# Ship-Capture — Zero-Friction Entity Creation

You are creating a new ship-flow entity from a captain's free-form description. Goal: from idea → draft entity file in **1 step** (vs the manual 6-step process: workflow-dir lookup, frontmatter recall, slug naming, file write, git add, status check).

This skill solves the friction signal documented during the 2026-04-19 D2/D3/D4 audit: when capture takes 6 steps, captain skips it and ideas evaporate as "deferred from..." references in other entities. Zero-friction capture preserves the dark-matter work.

## Input parsing

Captain's invocation looks like one of:
- `/ship-flow:ship-capture "Move ROADMAP/PRODUCT update to git hook"`
- `/ship-flow:ship-capture "Refactor verify→ship→done complexity" --priority P2 --epic`
- `/ship-flow:ship-capture "Tier 1 capture skill" --parent 050 --depends-on 049`
- (chat) "capture this as ship-flow: ROADMAP update should be in a hook"

Extract:
1. **Description** — the free-form text (positional, required). If invoked from chat without slash, lift the captain's most recent intent from the message.
2. **--priority** — P0 | P1 | P2 | P3 (default: P3)
3. **--epic** — set `entity_type: epic`, use epic template body
4. **--parent <id>** — zero-padded entity ID (e.g., "050")
5. **--depends-on <ids>** — comma-separated entity IDs (e.g., "049,050")
6. **--source <text>** — override default source string

If description is missing or empty → ask: "What should I capture?" Do not guess.

---

## Step 1: Detect workflow directory

```bash
WORKFLOW_DIR=$(grep -l "^commissioned-by:" docs/*/README.md 2>/dev/null | head -1 | xargs -I{} dirname {})
[ -z "$WORKFLOW_DIR" ] && WORKFLOW_DIR="docs/ship-flow"
```

If `$WORKFLOW_DIR` doesn't exist as a directory → tell captain: *"No commissioned ship-flow workflow found. Run `/ship-flow:ship-onboard` first to bootstrap, or confirm to create `docs/ship-flow/` here."* Wait for confirmation before proceeding.

---

## Step 2: Generate slug from description

Apply this transformation deterministically (no LLM call — slug is mechanical, captain can rename in body if needed):

1. Lowercase the description
2. Drop stop words: `a, an, the, of, for, to, in, on, at, with, this, that, is, are, be, into, from, and, or, but`
3. Replace non-alphanumeric runs with single hyphen
4. Trim leading/trailing hyphens
5. Truncate to **6 words max** (split by hyphen, keep first 6, rejoin)
6. Check collision in `$WORKFLOW_DIR/*.md` and `$WORKFLOW_DIR/_archive/*.md` — append `-2`, `-3`, etc. as needed (max 5 attempts; if still colliding, ask captain for explicit slug)

Examples:
- `"Move ROADMAP/PRODUCT update to git hook"` → `move-roadmap-product-update-git-hook`
- `"Tier 1 capture skill — entity creation"` → `tier-1-capture-skill-entity-creation` → truncate → `tier-1-capture-skill-entity-creation` (5 words, OK)
- Collision case: `tier-1-capture-skill` exists → use `tier-1-capture-skill-2`

Show captain the proposed slug in the final report (Step 5). Captain can edit the file's filename later if dissatisfied — slug is not load-bearing.

---

## Step 3: Build frontmatter

**Standard template** (default):

```yaml
---
id:
title: {description, sentence-cased, ≤ 80 chars — truncate with ellipsis if longer}
status: draft
source: "{--source value, or 'captain capture session {YYYY-MM-DD}'}"
started:
completed:
verdict:
priority: {--priority or P3}
score:
worktree:
parent: {--parent or empty}
depends-on: {--depends-on as YAML list, or []}
tracker:
issue:
external_id:
pr:
token_budget:
token_actual:
---
```

**Epic template** (when `--epic`):

```yaml
---
id:
title: {description}
status: draft
source: "{--source or default}"
started:
completed:
verdict:
priority: {--priority or P3}
score:
worktree:
entity_type: epic
children: []
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

Note: `id:` is intentionally left empty. The next stage (typically ship-sharp) assigns a sequential ID. Some captains assign manually before sharp — both are fine.

---

## Step 4: Build body

**Standard body**:

```markdown
{description as-is, formatted as a paragraph}

---

> Next: when ready to define problem framing + done criteria, run `/ship-flow:ship-sharp {slug}`. Captain gates the sharp stage; agents handle plan/execute/verify/ship autonomously after.
```

**Epic body** (when `--epic`):

```markdown
{description as-is, formatted as a paragraph}

## Decomposition

_Captain or ship-sharp epic mode will populate this section with vertical slice children._

## Cross-Entity Contracts

_Shared decisions/contracts that bind children together (filled by ship-sharp epic mode)._

---

> Next: run `/ship-flow:ship-sharp {slug}` to enter epic mode — research architecture, propose decomposition into 3-5 vertical slice children, and write Cross-Entity Contracts.
```

---

## Step 5: Write file + stage (do NOT commit)

```bash
WORKFLOW_DIR="docs/ship-flow"  # or detected value from Step 1
SLUG="{computed slug}"
FILE="$WORKFLOW_DIR/$SLUG.md"

# Write the file (use heredoc or Write tool)
cat > "$FILE" <<'EOF'
{frontmatter}

{body}
EOF

git add "$FILE"
```

Use the `Write` tool to create the file (cleaner than heredoc). Then run `git add` via `Bash`.

**Do NOT commit.** Captain reviews and commits in their own flow — auto-commit would bypass their review and burn trust.

---

## Step 6: Report to captain

```
✓ Captured: {slug}
  Path:     {WORKFLOW_DIR}/{slug}.md
  Title:    {title}
  Priority: {priority}
  {parent: {id}}                # only if --parent was set
  {depends-on: [{ids}]}         # only if --depends-on was set
  {entity_type: epic}           # only if --epic

Already staged (review with `git diff --cached`).

Suggested next:
  • Edit body to add detail:    {WORKFLOW_DIR}/{slug}.md
  • Sharpen when ready:         /ship-flow:ship-sharp {slug}
  • View pipeline state:        spacedock status (or future: /ship-flow:ship-status)
```

If `--epic` was set, also append:
```
  • Capture child entities:     /ship-flow:ship-capture "<child desc>" --parent {epic-id-once-assigned}
```

---

## Edge cases

| Case | Handling |
|---|---|
| Description is empty / only whitespace | Ask: *"What should I capture?"* — do not guess from session context |
| Description < 3 words | Create anyway, but warn: *"Title is very short — searchability may suffer; consider editing the title field"* |
| Description > 500 chars | Confirm: *"This looks like a paste rather than a capture. Truncate title to first sentence, or use full text as body?"* |
| `--parent <id>` points to non-existent entity file | Warn but proceed — captain may be capturing parent next; forward references are valid |
| `--depends-on <ids>` includes non-existent ids | Same — warn but proceed |
| Workflow directory missing | See Step 1 — block on confirmation |
| Slug collision after 5 numbered attempts | Ask captain for explicit slug |
| Already > 50 entities at `status: draft` | Warn: *"You have N drafts. Consider triaging via `spacedock status` before adding more, or batch-promote via `/ship-flow:ship-sharp`."* — but proceed |

---

## Circuit breakers

- **Description ambiguity** (could parse 2+ ways) → ask captain to clarify, do not pick one silently
- **`--epic` + `--parent` together** → reject: *"Epic entities are top-level; they cannot have a parent. Drop `--parent` or drop `--epic`."*
- **File write fails** (permissions, disk full) → report exact error, do not retry silently

---

## Anti-patterns (don't do these)

- ❌ Auto-commit the new file — captain hasn't reviewed body yet
- ❌ Auto-assign sequential `id:` — that's ship-sharp's job (it knows current max)
- ❌ Call an LLM to "improve" the title — slug + title are deterministic from input; smartness is a separate skill
- ❌ Trigger ship-sharp automatically — capture is non-committal; sharpening is the captain's gate
- ❌ Suggest priority based on description sentiment — let captain set explicitly via `--priority`

---

## Why this skill exists (cite for future maintainers)

2026-04-19 audit (Musk-perspective ship-flow complexity reduction):
- Ship-flow has 7 stage skills (ship-onboard, ship-sharp, ship-plan, ship-execute, ship-verify, ship-review, ship-pr-feedback) but **0 capture/triage/ops skills**.
- GSD has ~60 skills covering full lifecycle including 6 capture skills (gsd-note, gsd-add-todo, gsd-add-backlog, gsd-plant-seed, gsd-add-phase, gsd-insert-phase).
- Friction signal: D4(2) + D4(3) cleanup work was deferred from a previous audit because manual entity creation (6 steps) exceeded captain's in-flight capacity.
- Tier 1 recommendation: 4 entry-point skills (ship-capture, ship-status, ship-next, ship-help) close 80% of the captain-facing friction gap with 1/15 of GSD's skill count.
- This is skill #1 of the Tier 1 set. Self-test: this skill should be used to capture its own siblings.

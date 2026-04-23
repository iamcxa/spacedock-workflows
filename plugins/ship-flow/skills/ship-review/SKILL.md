---
name: ship-review
description: "Use when verify stage passed and entity is ready for PR creation + canonical documentation sync. Agent-autonomous: architecture-canon mod + PR-body drafting + ROADMAP.md/PRODUCT.md updates + token cost summary. Dispatched by /ship to `planner` teammate (SendMessage). Output: `<entity-folder>/review.md`. Layer A delegation: pr-review-toolkit:review-pr for review agent philosophy."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# Ship-Review — REVIEW Stage (2.0)

You run REVIEW. Output: `<entity-folder>/review.md`. Dispatched by `/ship` to `planner` teammate via SendMessage (hot context from spec + plan authorship). No captain gate at this stage; captain decides merge after PR lands in `/ship` final stage.

**Pipeline position**: reads `verify.md` (must have PASS verdict) → invokes architecture-canon mod → drafts PR body → updates canonical docs → produces `review.md` → cross-review gate → advance to ship-final.

## Entity body contract (schema-as-prose)

- Reads: `verify.md` verdict (PASS required), `execute.md` execution log, `spec.md` problem / DC / user journey / architecture-impact, `plan.md` verification spec table, `PRODUCT.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `references/doc-format.md`.
- Writes: `<entity-folder>/review.md` sections — `## PR Draft` (title + body), `## ROADMAP.md Update` (conditional), `## PRODUCT.md Update` (conditional), `## Architecture Changes` (conditional, from canon mod), `## D2 Knowledge Candidates` (conditional), `## Token Summary`, `## Review Report` (verdict / stage_cost / timestamps).
- Side effects: ROADMAP.md Now → Shipped; PRODUCT.md capability + user story append.
- Full section-tag + field semantics: `plugins/ship-flow/references/entity-body-schema.yaml → stages.review`.

## Layer A delegation (Principle 6 Rule B)

`pr-review-toolkit:review-pr` (and specialized reviewer agents) owns PR review agent philosophy (code-reviewer / silent-failure-hunter / security-reviewer persona prompts, diff interpretation, finding severity classification). **Do NOT re-teach.** Ship-review wraps with Layer B augmentation:

- Verify verdict pre-check (PASS required; block-on-fail).
- Architecture-canon mod invocation (atomic ARCHITECTURE.md patch with read-first CAS, before PR body is drafted).
- PR body drafting from canonical entity sections (Problem / User Journey / DC+Verification / Changes / Architecture Changes / Quality Gate).
- Canonical doc sync (ROADMAP.md + PRODUCT.md via patch-map.sh, pathspec-safe).
- Token cost summary + D2 knowledge candidate surfacing.

**pr-review-toolkit invocation sizing** (captain Q3 answer, Wave 6):
- `appetite: big-batch` → ALWAYS invoke `pr-review-toolkit:review-pr`
- `appetite: medium-batch` → OPTIONAL (entity captain-opt-in via frontmatter `pr-review-opt-in: true`)
- `appetite: small-batch` → SKIP (diff too narrow for multi-persona review to add value)

Note: ship-verify invokes atomic reviewers (`pr-review-toolkit:code-reviewer` / `silent-failure-hunter` + `ui-verify`) for diff classification during quality gating; ship-review invokes the composite `pr-review-toolkit:review-pr` for PR body quality — different concerns.

---

## Flow

**Phases (TaskCreate sub-tasks — inherit from /ship umbrella when pipeline-dispatched):**
`read-verify` → `arch-canon-mod` → `vcs-detect` → `pr-body-draft` → `roadmap-update` → `product-update` → `token-summary` → `d2-surface` → `cross-review` → `emit-review.md`

### Step 1 — Read verify verdict + entity sections

Record stage-start ISO. Extract via `bash plugins/ship-flow/lib/extract-section.sh <entity-file> <tag>`. From verify.md: `verdict.status` = `passed` or `PASS` (legacy fallback `## Verify Report` → `Verdict: PASS`). From execute.md: execution log (for PR body Changes section). From spec.md: Problem, User Journey, Done Criteria, Shape Output (if present), Size Assessment, Architecture Impact (if present).

**Pre-check**: verdict != PASS → write `## Review Report status: blocked, reason: verify verdict <actual>, expected passed` and return. Never proceed without PASS.

### Step 1.5 — Invoke architecture-canon mod (before PR body)

Runs before Step 2 so arch commits land on branch and PR body can cite their SHAs.

**Trigger check**:
```bash
bash plugins/ship-flow/lib/extract-section.sh "$ENTITY_FILE" architecture-impact 2>/dev/null | grep -qE "^after:[[:space:]]*\|"
```

No `architecture-impact` section OR empty `after:` block → skip silently (mod also noops internally; double-check saves a subshell).

**Verification reminder** (INVARIANTS Captain-Gate #6): if `architecture-impact.after` substantially replaces an existing section OR contains ≥5 lower-confidence claims (novel pattern / consumer-list / file:line citations), dispatch fresh-context verification subagent BEFORE running the mod. Same principle applies at Steps 3 / 4 for substantial ROADMAP / PRODUCT entries.

**When triggered**:
```bash
ENTITY_FILE="$ENTITY_FILE" bash docs/ship-flow/_mods/architecture-canon.md
```

Mod sequence: (1) freshness-check captured `before:` against current ARCHITECTURE.md (exit 1 = stale); (2) atomic patch of `target_section` via patch-map.sh with read-first CAS (commit: `docs(architecture): #{id} — {summary}`); (3) append Decisions table row (commit: `docs(architecture-index): #{id}`).

**On mod success**: capture two commit SHAs for PR body:
```bash
ARCH_COMMIT=$(git log -2 --format=%H --grep='^docs(architecture): #' | head -1)
ADR_COMMIT=$(git log -2 --format=%H --grep='^docs(architecture-index): #' | head -1)
```
PR body includes `## Architecture Changes` section.

**On mod failure** (exit non-zero): HALT ship-review; write `## Review Report status: blocked, reason: architecture-canon mod failed: exit {rc}`. Captain reconciles (most common: re-extract `before:` because parallel session patched ARCHITECTURE.md post-sharp). Exit codes: 1 = freshness / missing fields, 6 = CAS mismatch, 9 = mermaid validation.

### Step 1.7 — VCS detection

```bash
git remote -v 2>/dev/null | grep -q "github\.com" && echo "vcs=github" || \
git remote -v 2>/dev/null | grep -q "gitlab\.com" && echo "vcs=gitlab" || \
echo "vcs=unknown"
```

Override from `docs/<wf>/README.md` frontmatter `commands:` block if present (pr_create / pr_view / pr_comment / pr_close). Resolve VCS command variables:

| Variable | github | gitlab |
|---|---|---|
| `{commands.pr_create}` | `gh pr create` | `glab mr create` |
| `{commands.pr_view}` | `gh pr view` | `glab mr view` |
| `{commands.pr_comment}` | `gh pr comment` | `glab mr comment` |

Unknown VCS → stop; ask captain to add `commands:` block to workflow README frontmatter.

### Step 2 — Draft PR body (write to review.md)

**Do NOT push or `gh pr create` here.** Ship-final stage (in `/ship` skill) creates the PR from this drafted body. Ship-review only writes `## PR Draft` to `review.md`.

PR body template:

```markdown
Title: {entity title}

Body:
## Problem
{from spec.md → Problem}

## User Journey
{from spec.md → User Journey — end-to-end flow}

## Done Criteria + Verification
{Full UAT table from verify.md → UAT section: DC / Type / Assertion / Verify Procedure / Result}

## Changes
{from execute.md → Execution Log — task summary with commit SHAs}

## Architecture Changes          ← include ONLY if architecture-canon mod ran
- Patched ARCHITECTURE.md → {target_section}: {summary} ({ARCH_COMMIT short-SHA})
- Appended Decisions index row for #{entity-id} ({ADR_COMMIT short-SHA})

## Quality Gate
{from verify.md → Quality Gate 5-check results}

Entity: #{entity-id}
Ship-flow: shape → plan → execute → verify → review → ship-final (autonomous)
Tracker: {tracker + issue, if set}
Cost: ${token_actual} (budget: ${token_budget})
```

The ship-final stage (in `/ship` skill) reads this drafted body to assemble the `gh pr create` / `glab mr create` invocation.

### Step 3 — Update ROADMAP.md (two atomic patches)

Skip if `ROADMAP.md` absent (no error).

**3.1 Remove from Now section**:
```bash
BEFORE_HASH=$(sha256sum ROADMAP.md 2>/dev/null | awk '{print $1}' || shasum -a 256 ROADMAP.md | awk '{print $1}')
bash plugins/ship-flow/lib/patch-map.sh \
  --if-hash="$BEFORE_HASH" --mode=remove-row --match="{entity.slug}" --section=now \
  --commit-as="ship: remove {entity.id} from Now" ROADMAP.md
```
Exit 6 (stale hash — parallel session wrote between extract and patch): re-read + recompute + retry. Max 3 retries before BLOCKED. Idempotent: row already gone → no-op exit 0.

**3.2 Append to Shipped section** (recompute hash first; file changed in 3.1):
```bash
AFTER_HASH=$(sha256sum ROADMAP.md 2>/dev/null | awk '{print $1}' || shasum -a 256 ROADMAP.md | awk '{print $1}')
NEW_ROW="| {entity.id} | {title} | {one-sentence from Problem, present tense per doc-format.md} | {today} | {PR ⏳ or link} |"
bash plugins/ship-flow/lib/patch-map.sh \
  --if-hash="$AFTER_HASH" --mode=append --section=shipped \
  --commit-as="ship: record {entity.id} in Shipped" ROADMAP.md <<<"$NEW_ROW"
```

**ID collision** (cross-workflow): if `{entity.id}` already in current Shipped body → suffix with workflow dir: `{id}-{workflow-dir-name}` (e.g., `005-ship-flow`).

**3.3 Cost Calibration** (unchanged; captain-managed prose, no marker): if `## Cost Calibration` table exists and `token_actual` known, increment size row's Sample count and recalc Median if sample ≥3. Manual Edit tool is the right tool here.

### Step 4 — Update PRODUCT.md

Skip if absent. Read `references/doc-format.md` for exact formats; follow derivation rules, do not improvise.

**4.1 Append capability bullet** to `## Current Capabilities`:
- Format: `- {What it does} — {why it matters in ≤10 words} (#{entity-id})`
- If shape ran → derive from US-1 "I want" clause. Else → from Problem first sentence rewritten as capability.

```bash
BEFORE_HASH=$(sha256sum PRODUCT.md 2>/dev/null | awk '{print $1}' || shasum -a 256 PRODUCT.md | awk '{print $1}')
BULLET="- {derived line}"
bash plugins/ship-flow/lib/patch-map.sh \
  --if-hash="$BEFORE_HASH" --mode=append --section=capabilities \
  --commit-as="ship: add capability for {entity.id}" PRODUCT.md <<<"$BULLET"
```

Domain sub-header grouping deferred to a future reorg entity; append to end for now.

**4.2 Add user story (JTBD format)** (unchanged — prose; no marker):
- Shape ran → copy accepted stories from spec.md Shape Output.
- No shape → generate ONE story: Persona (match PRODUCT.md "Who It Serves", default Captain); Action (from DC's primary observable change); Outcome (from Problem's "why it matters"). Deduplicate.

**4.3 Update constraints** (rare; Edit tool, no marker) only if feature explicitly relaxes or adds a constraint.

**4.4 Cross-check consistency** (from doc-format.md):
- ROADMAP Shipped "Why it existed" ↔ PRODUCT capability "why it matters" (same idea, different format).
- North Star in PRODUCT.md Vision ↔ ROADMAP.md North Star (identical text).

### Step 5 — Token summary

Read `token_actual` from entity frontmatter (FO-accumulated). Read `token_budget` from spec.md Size Assessment.

```markdown
## Token Summary
Budget: ${token_budget}
Actual: ${token_actual}
Ratio: {actual/budget}x
```

Ratio > 2.0 → note in Review Report as `⚠️ over budget`.

### Step 6 — D2 knowledge surfacing

Scan execute.md and verify.md `## Knowledge Captures` for `[D2-candidate]` tags. Write `## D2 Knowledge Candidates` section listing them with captain prompt:

> **Knowledge candidates** — these patterns generalized beyond this entity. Add to CLAUDE.md?
> - {D2-1}
> - {D2-2}
>
> Reply "yes" to add all, or specify which to accept.

No candidates → skip silently.

### Step 7 — Cross-review gate (Principle 6 Rule C)

Dispatch cross-review to `executer` teammate (reviews PR body + doc-sync accuracy) or fresh sonnet (no team). Upgrade fresh **opus** when `appetite: big-batch`.

**Layer A expansion per sizing rule** (see Layer A delegation section above): `appetite: big-batch` → ALWAYS invoke `Skill: pr-review-toolkit:review-pr` for multi-persona PR body review. `appetite: medium-batch` → invoke only if entity frontmatter `pr-review-opt-in: true`. `appetite: small-batch` → skip (diff too narrow for multi-persona value).

5-factor rubric adapted for review stage:

1. **Feasibility** — PR size reasonable; branch ready for captain smoke?
2. **Executable scope** — review scope matches actual diff (no omitted file / no scope creep)?
3. **Quality** — no silent failures; every DC verified in UAT table; architecture commits land BEFORE PR body cites them?
4. **DC adequacy** — PR body's DC+Verification table is reproducible (copy-paste the procedure)?
5. **Canonical sync** — ROADMAP + PRODUCT updated; PR body reflects canonical deltas (Architecture Changes / Cost Calibration if applicable)?

Verdict: **PROCEED** / **VETO** (loop to fix sections) / **PROMPT_CAPTAIN**.

### Step 8 — Emit review.md

Write via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=review --entity=<id>-<slug> --content=<draft-path>` (Wave 5 primitive at commit `acd73545`; atomic + pathspec-lock).

Review.md sections: `## PR Draft`, `## ROADMAP.md Update` (conditional), `## PRODUCT.md Update` (conditional), `## Architecture Changes` (conditional), `## D2 Knowledge Candidates` (conditional), `## Token Summary`, `## Review Report` (status: shipped-ready / stage_cost / tasks / Verify results / ROADMAP+PRODUCT update status / timestamps / duration).

Return to /ship; advance to ship-final stage (PR creation + captain merge gate).

**Frontmatter write scope — ONLY `token_actual`.** Do NOT write `status`, `completed`, `verdict`, `pr`, `worktree` — these are FO-owned at terminal transition or pr-merge mod's concern.

---

## Invariants + red flags (STOP if violated)

- Verify verdict must be PASS. Anything else → BLOCKED, return to FO.
- Architecture-canon mod is load-bearing: any `architecture-impact` section → mod MUST run before PR body drafted (so SHAs can be cited). Mod failure → HALT.
- Do NOT push or `gh pr create` here — ship-final owns PR creation. Only draft PR body to review.md.
- ROADMAP / PRODUCT patches use `patch-map.sh` with `--if-hash` read-first CAS. Exit 6 (stale) → re-read + retry, max 3.
- `--if-hash` retry cap: 3. Beyond → BLOCKED.
- Cost Calibration + user story + constraint updates are prose-manual (Edit tool); the three don't use patch-map.sh.
- Frontmatter write scope strict: only `token_actual`.
- Layer A delegation (`pr-review-toolkit:*`) owns PR review agent personas — re-teaching = Principle 6 Rule B violation.
- Cross-review VETO cap 2 rounds; round 3 → PROMPT_CAPTAIN.

## Circuit breakers

- Verify verdict != PASS → do not proceed; report back to FO.
- Architecture-canon mod failure → HALT, write blocked Review Report.
- Patch-map `--if-hash` exit 6: max 3 retries.
- ROADMAP / PRODUCT update failure: log as Learning, proceed non-blocking.
- Token overrun (actual > budget × 2): note in Review Report, do not block.
- Total stage >15 min elapsed → write `review.md` partial + `⚠️ INCOMPLETE` markers + Review Report status=partial. Never exit without emitting review.md.

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml → stages.review`.
- Stage writer: `plugins/ship-flow/lib/write-stage-artifact.sh`.
- Section extraction: `plugins/ship-flow/lib/extract-section.sh`.
- Atomic doc patches: `plugins/ship-flow/lib/patch-map.sh` (read-first CAS via `--if-hash`).
- Architecture-canon mod: `docs/ship-flow/_mods/architecture-canon.md`.
- Doc format rules: `plugins/ship-flow/references/doc-format.md`.
- Layer A: `pr-review-toolkit:review-pr` (PR review agent personas — ALWAYS big-batch; OPTIONAL medium-batch via `pr-review-opt-in: true`; SKIP small-batch).
- Principle 6: `plugins/ship-flow/INVARIANTS.md`.
- MEMORY: #14/#25/#37 (pathspec / staging), #30 (verification-dispatch — applies to substantial ROADMAP/PRODUCT entries), #35 (dispatch discipline amended by Principle 6), opus-4.7-naturally-does (2026-04-23 harness diet).

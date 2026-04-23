---
name: ship-review
description: "Use when verify stage passed and entity is ready for PR creation + canonical documentation sync. Agent-autonomous: 4-doc canonical dispatch (ARCHITECTURE.md / PRODUCT.md / README.md / ROADMAP.md) via `planner` teammate + PR-body drafting + token cost summary. Dispatched by /ship to `planner` teammate (SendMessage). Output: `<entity-folder>/review.md`. Layer A delegation: pr-review-toolkit:review-pr for review agent philosophy."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# Ship-Review — REVIEW Stage (2.0)

You run REVIEW. Output: `<entity-folder>/review.md`. Dispatched by `/ship` to `planner` teammate via SendMessage (hot context from spec + plan authorship). No captain gate at this stage; captain decides merge after PR lands in `/ship` final stage.

**Pipeline position**: reads `verify.md` (must have PASS verdict) → dispatches 4-doc canonical patches to `planner` → drafts PR body → produces `review.md` → cross-review gate → advance to ship-final.

## Entity body contract (schema-as-prose)

- Reads: `verify.md` verdict (PASS required), `execute.md` execution log, `spec.md` problem / DC / user journey / architecture-impact / product-impact / readme-impact blocks (per child), parent `roadmap-phase`, `PRODUCT.md`, `ARCHITECTURE.md`, `README.md`, `ROADMAP.md`, `references/doc-format.md`.
- Writes: `<entity-folder>/review.md` sections — `## PR Draft` (title + body), `## Canonical Docs Update` (4 commit SHAs or skip-rationale per doc), `## D2 Knowledge Candidates` (conditional), `## Token Summary`, `## Review Report` (verdict / stage_cost / timestamps).
- Side effects: ARCHITECTURE.md / PRODUCT.md / README.md / ROADMAP.md patched (by `planner` dispatch — NOT by this skill directly).
- Full section-tag + field semantics: `plugins/ship-flow/references/entity-body-schema.yaml → stages.review`.

## Layer A delegation (Principle 6 Rule B)

`pr-review-toolkit:review-pr` (and specialized reviewer agents) owns PR review agent philosophy (code-reviewer / silent-failure-hunter / security-reviewer persona prompts, diff interpretation, finding severity classification). **Do NOT re-teach.** Ship-review wraps with Layer B augmentation:

- Verify verdict pre-check (PASS required; block-on-fail).
- **Canonical docs update**: dispatched to `planner` (named teammate via SendMessage) — leverages Principle 6 Rule A continuity (shape → plan → execute → verify context). Planner holds hot context across the pitch; mechanical patching of 4 docs benefits from that context (cross-section aggregation, prose-varying README judgment).
- PR body drafting from canonical entity sections (Problem / User Journey / DC+Verification / Changes / Architecture Changes / Quality Gate).
- Token cost summary + D2 knowledge candidate surfacing.

**pr-review-toolkit invocation sizing** (captain Q3 answer, Wave 6):
- `appetite: big-batch` → ALWAYS invoke `pr-review-toolkit:review-pr`
- `appetite: medium-batch` → OPTIONAL (entity captain-opt-in via frontmatter `pr-review-opt-in: true`)
- `appetite: small-batch` → SKIP (diff too narrow for multi-persona review to add value)

Note: ship-verify invokes atomic reviewers (`pr-review-toolkit:code-reviewer` / `silent-failure-hunter` + `ui-verify`) for diff classification during quality gating; ship-review invokes the composite `pr-review-toolkit:review-pr` for PR body quality — different concerns.

**Rule A Fallback reminder**: when `SendMessage(planner)` for the canonical doc dispatch is unavailable (phantom team / no response) or the dispatched fresh Agent stalls, fall back per INVARIANTS Principle 6 Rule A Fallback — fresh `Agent(subagent_type: general-purpose)` with captured entity sections + doc pathspecs in the prompt. If canonical doc patches are already partially committed when a subagent stalls, check `git log` before redoing (may have landed pre-stall). Inline patching via `patch-map.sh --if-hash` is the last resort.

---

## Flow

**Phases (TaskCreate sub-tasks — inherit from /ship umbrella when pipeline-dispatched):**
`read-verify` → `dispatch-canonical-patches` → `vcs-detect` → `pr-body-draft` → `token-summary` → `d2-surface` → `cross-review` → `emit-review.md`

### Step 1 — Read verify verdict + entity sections

Record stage-start ISO. Extract via `bash plugins/ship-flow/lib/extract-section.sh <entity-file> <tag>`. From verify.md: `verdict.status` = `passed` or `PASS`. From execute.md: execution log (for PR body Changes section). From spec.md (aggregated across children): Problem, User Journey, Done Criteria, Shape Output, Size Assessment, `architecture-impact`, `product-impact`, `readme-impact`. From parent entity (if `parent:` set): `roadmap-phase`.

**Pre-check**: verdict != PASS → write `## Review Report status: blocked, reason: verify verdict <actual>, expected passed` and return. Never proceed without PASS.

### Step 2 — Dispatch canonical doc patches to `planner`

SendMessage to `planner` teammate with a structured prompt. Planner already has hot context from shape + plan stages; this dispatch is the canonical-sync work, not re-discovery.

**Dispatch prompt template**:

> Draft canonical doc patches for pitch `<id>-<slug>`. Read entity children's `architecture-impact`, `product-impact`, `readme-impact` blocks + parent `roadmap-phase` + verify verdict. Aggregate per target_section. Apply patches atomically:
>
> - **ARCHITECTURE.md** — per aggregated `architecture-impact` section: `bash plugins/ship-flow/lib/patch-map.sh --if-hash=<sha> --section=<target_section> --commit-as="docs(architecture): #<id> — <summary>" ARCHITECTURE.md`. Then append Decisions index row for #<id> via same primitive.
> - **PRODUCT.md** — per aggregated `product-impact` section: `bash plugins/ship-flow/lib/patch-map.sh --if-hash=<sha> --section=<target_section> --commit-as="docs(product): #<id> — <summary>" PRODUCT.md`. Covers user stories, constraints, capabilities.
> - **README.md** — per `readme-impact` block: Edit tool with before/after matching (README is prose-heavy, typically NO section tags → DO NOT use patch-map.sh). Commit via explicit pathspec: `git add -- README.md && git commit -m "docs(readme): #<id> — <summary>" -- README.md`. If block has `entry_critical: true`, note it in commit body.
> - **ROADMAP.md** — status flip: `patch-map.sh --if-hash=<sha> --mode=remove-row --match=<slug> --section=now --commit-as="ship: remove #<id> from Now" ROADMAP.md` then `--mode=append --section=shipped --commit-as="ship: record #<id> in Shipped"` with new row.
>
> Discipline: read-first CAS via `--if-hash` on patch-map.sh invocations. Exit 6 (stale hash) → re-read + retry, max 3 rounds per doc. Explicit pathspec at commit-time (MEMORY #14/#25/#37). No `-a`/`-A`. Commit each doc separately.
>
> Report back with: 4 commit SHAs (or skip-rationale per doc if no matching impact block) + per-doc diff summary.

**Verification reminder** (INVARIANTS Captain-Gate #6): if any impact block's `after:` substantially replaces an existing section OR contains ≥5 lower-confidence claims, planner dispatches fresh-context verification subagent BEFORE patching. Same principle applies to prose-heavy README edits.

**Blocker conditions**:
- Planner reports `patch-map.sh --if-hash` exit 6 after 3 retries on any doc → write `## Review Report status: blocked, reason: canonical doc <name> stale hash; parallel session contaminated` and return.
- Planner reports a per-child impact block fails schema validation (missing `target_section` / malformed `before:` / `after:` empty) → HALT ship-review; write `## Review Report status: blocked, reason: impact block schema violation on <child-id>`. Fix is in shape stage.

**On dispatch success**: capture planner's reported SHAs. Draft `## Canonical Docs Update` section in review.md:

```markdown
## Canonical Docs Update

- ARCHITECTURE.md: {ARCH_COMMIT short-SHA} — {summary} (or "skipped — no architecture-impact block")
- PRODUCT.md: {PRODUCT_COMMIT short-SHA} — {summary} (or "skipped — no product-impact block")
- README.md: {README_COMMIT short-SHA} — {summary} (or "skipped — no readme-impact block")
- ROADMAP.md: {ROADMAP_COMMIT short-SHA} — status flipped (or "skipped — no parent roadmap-phase")
```

### Step 3 — VCS detection

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

### Step 4 — Draft PR body (write to review.md)

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

## Canonical Docs Update
- ARCHITECTURE.md → {target_section}: {summary} ({ARCH_COMMIT short-SHA})  ← omit line if skipped
- PRODUCT.md → {target_section}: {summary} ({PRODUCT_COMMIT short-SHA})    ← omit line if skipped
- README.md → {section}: {summary} ({README_COMMIT short-SHA})             ← omit line if skipped; flag ⚠ entry_critical if applicable
- ROADMAP.md: status flipped Now → Shipped ({ROADMAP_COMMIT short-SHA})    ← omit line if skipped

## Quality Gate
{from verify.md → Quality Gate 5-check results}

Entity: #{entity-id}
Ship-flow: shape → plan → execute → verify → review → ship-final (autonomous)
Tracker: {tracker + issue, if set}
Cost: ${token_actual} (budget: ${token_budget})
```

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

Dispatch cross-review to `executer` teammate (reviews PR body + canonical-docs dispatch accuracy) or fresh sonnet (no team). Upgrade fresh **opus** when `appetite: big-batch`.

**Layer A expansion per sizing rule** (see Layer A delegation section above): `appetite: big-batch` → ALWAYS invoke `Skill: pr-review-toolkit:review-pr` for multi-persona PR body review. `appetite: medium-batch` → invoke only if entity frontmatter `pr-review-opt-in: true`. `appetite: small-batch` → skip.

5-factor rubric adapted for review stage:

1. **Feasibility** — PR size reasonable; branch ready for captain smoke?
2. **Executable scope** — review scope matches actual diff (no omitted file / no scope creep)?
3. **Quality** — no silent failures; every DC verified in UAT table; canonical commits land BEFORE PR body cites them?
4. **DC adequacy** — PR body's DC+Verification table is reproducible (copy-paste the procedure)?
5. **Canonical sync** — 4-doc audit:
   - **ARCHITECTURE.md**: architecture-impact blocks aggregated cleanly per target_section? No section-tag corruption (patch-map.sh CAS held)?
   - **PRODUCT.md**: constraints / user stories align with spec.md intent?
   - **README.md**: `entry_critical` readme-impact blocks carefully applied (prose-varying needs closer audit)? Install / usage prose reads naturally?
   - **ROADMAP.md**: status flip matches pitch actual verdict? Shipped row carries correct date + PR placeholder?

Verdict: **PROCEED** / **VETO** (loop to fix sections) / **PROMPT_CAPTAIN**.

**Circuit breaker**: if `SendMessage(executer)` is unresponsive (phantom team / timeout / fresh-Agent stall), fall back per INVARIANTS Rule A Fallback — fresh sonnet by default, fresh opus on `big-batch`. Do not block on an unresponsive reviewer.

### Step 8 — Emit review.md

Write via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=review --entity=<id>-<slug> --content=<draft-path>` (Wave 5 primitive at commit `acd73545`; atomic + pathspec-lock).

Review.md sections: `## PR Draft`, `## Canonical Docs Update` (4 commit SHAs or skip-rationale per doc), `## D2 Knowledge Candidates` (conditional), `## Token Summary`, `## Review Report` (status / stage_cost / planner dispatch cost / Verify results / canonical sync status / timestamps / duration).

Return to /ship; advance to ship-final stage (PR creation + captain merge gate).

**Frontmatter write scope — ONLY `token_actual`.** Do NOT write `status`, `completed`, `verdict`, `pr`, `worktree` — these are FO-owned at terminal transition or pr-merge mod's concern.

---

## Invariants + red flags (STOP if violated)

- Verify verdict must be PASS. Anything else → BLOCKED, return to FO.
- Canonical docs update is dispatched to `planner` teammate — ship-review does NOT patch docs directly. Planner holds hot context; patches are mechanical + prose-sensitive for README.
- patch-map.sh `--if-hash` read-first CAS is the only safe concurrent-write pattern for ARCHITECTURE / PRODUCT / ROADMAP. Exit 6 (stale) → re-read + retry, max 3.
- README.md uses Edit tool (prose-heavy, no section tags typically); DO NOT patch-map.sh on README.
- Explicit pathspec at commit-time on every doc commit (MEMORY #14/#25/#37). No `-a`/`-A`.
- Do NOT push or `gh pr create` here — ship-final owns PR creation. Only draft PR body to review.md.
- Frontmatter write scope strict: only `token_actual`.
- Layer A delegation (`pr-review-toolkit:*`) owns PR review agent personas — re-teaching = Principle 6 Rule B violation.
- Cross-review VETO cap 2 rounds; round 3 → PROMPT_CAPTAIN.
- 4-doc canonical-sync audit in cross-review must cover all 4 docs (or explicit skip-rationale per doc).

## Circuit breakers

- Verify verdict != PASS → do not proceed; report back to FO.
- Planner reports patch-map `--if-hash` exit 6 after 3 retries on any doc → HALT, write blocked Review Report.
- Impact block schema violation (missing target_section / malformed before-after) → HALT; fix in shape stage.
- Token overrun (actual > budget × 2): note in Review Report, do not block.
- Total stage >15 min elapsed → write `review.md` partial + `⚠️ INCOMPLETE` markers + Review Report status=partial. Never exit without emitting review.md.

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml → stages.review` (plus `architecture-impact`, `product-impact`, `readme-impact`, `roadmap-phase` block schemas).
- Stage writer: `plugins/ship-flow/lib/write-stage-artifact.sh` (landed commit `acd73545`).
- Section extraction: `plugins/ship-flow/lib/extract-section.sh`.
- Atomic doc patches: `plugins/ship-flow/lib/patch-map.sh` (read-first CAS via `--if-hash`) — ARCHITECTURE / PRODUCT / ROADMAP only.
- Doc format rules: `plugins/ship-flow/references/doc-format.md`.
- Layer A: `pr-review-toolkit:review-pr` (PR review agent personas — ALWAYS big-batch; OPTIONAL medium-batch via `pr-review-opt-in: true`; SKIP small-batch).
- Principle 6: `plugins/ship-flow/INVARIANTS.md`.
- MEMORY: #14/#25/#37 (pathspec / staging), #30 (verification-dispatch — applies to substantial canonical-doc entries), #35 (dispatch discipline amended by Principle 6), opus-4.7-naturally-does (2026-04-23 harness diet).

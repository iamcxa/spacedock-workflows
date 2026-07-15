---
name: ship-review
description: "Use when verify passed and ship-flow needs review, PR readiness, PR body drafting, or canonical docs sync. Layer A delegation: pr-review-toolkit:review-pr owns PR review persona philosophy."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# Ship-Review — REVIEW Stage (2.0)

You run REVIEW. Output: `<entity-folder>/review.md`. Dispatched by `/ship` to `planner` teammate via SendMessage (hot context from spec + plan authorship). No captain gate at this stage; captain decides merge after PR lands in `/ship` final stage.

**Pipeline position**: reads `verify.md` (must have PASS verdict) → dispatches 4-doc canonical patches to `planner` → drafts PR body → produces `review.md` → cross-review gate → advance to ship-final.

## Boot Self-Check

Run before any review work. Stop and SendMessage(FO) if any check fails.

1. **Entity status**: read entity frontmatter `status:` — must be `verify`. If `execute` → verify not done; if `review` → review already ran (check for re-entry).
2. **verify.md PASS**: `<entity-folder>/verify.md` exists AND `## Verify Report` verdict = PASS. If FAIL or missing → SendMessage(FO): "verify.md has FAIL verdict — review cannot proceed."
3. **Hand-off to Review present**: entity body contains `### Hand-off to Review` block. If absent → SendMessage(FO): "Missing Hand-off to Review — verifier did not complete handoff."
4. **Canonical docs readable**: `PRODUCT.md`, `ARCHITECTURE.md`, `README.md`, `ROADMAP.md` all exist at repo root. If any missing → note in review.md skip-rationale (non-blocking for docs that don't apply).
5. **Planner teammate**: verify `planner` teammate is reachable (SendMessage test). If unresponsive → use Rule A Fallback for canonical docs dispatch.
6. **Density-aware skill load** (T3.4): read `answers_density` from entity frontmatter. `high` → auto-load framework skills per ship-runtime-detect Step R6; skip FO ask. `low|vacuum` → SendMessage(FO) with proposed skill list; wait for confirmation.
7. **Canonical doc sync mod**: read `docs/ship-flow/_mods/canonical-doc-sync.md` when present. This mod defines doc timing for `ARCHITECTURE.md`, `PRODUCT.md`, `ROADMAP.md`, and umbrella closeout.
8. **Contribution contract**: read adopter `docs/ship-flow/_mods/contribution-contract.md` when present, otherwise the plugin copy. Resolve the pull request's base ref/SHA from the active PR and pass it explicitly as `BASE_REF` (or `PR_BASE_SHA`); never assume a branch name. Before any review or reviewer spend, execute that mod's checker-resolution block and, when `gate_required=true`, run the resolved checker on the merge-base-to-HEAD changed paths with `execute.md` as declaration input. An adopter map requires its adjacent adopted checker; only a source repository with no adopter map may use the plugin checker and default map. A repository with no adopted bundle and no plugin contribution-path change records the resolver's no-op skip, matching generic CI. Exit 1 returns incomplete paired work to execute. Exit 2 is BLOCKED because the bundle, base, map, or invocation is invalid. Record the exact command/result; worker self-attestation is not evidence.

## Entity body contract (schema-as-prose)

- Reads: `verify.md` verdict (PASS required), `execute.md` execution log, resolved shape artifact (`shape.md`; legacy `spec.md` fallback alias) problem / DC / user journey / architecture-impact / product-impact / readme-impact blocks (per child), parent `roadmap-phase`, `PRODUCT.md`, `ARCHITECTURE.md`, `README.md`, `ROADMAP.md`, `references/doc-format.md`, `docs/ship-flow/_mods/canonical-doc-sync.md`.
- Writes: `<entity-folder>/review.md` sections — `## PR Draft` (title + one-line reference to ship-final composition; NOT full prose — 129.3 CD-2), `## Per-Feature Retrospective` (compact), `## Canonical Docs Update` (4 commit SHAs or skip-rationale per doc), `## D2 Knowledge Candidates` (conditional), `## Token Summary`, `## Review Report` (verdict / stage_cost / timestamps).
- Side effects: ARCHITECTURE.md / PRODUCT.md / README.md / ROADMAP.md patched (by `planner` dispatch — NOT by this skill directly).
- Full section-tag + field semantics: `plugins/ship-flow/references/entity-body-schema.yaml → stages.review`.

## Layer A delegation (Principle 6 Rule B)

`pr-review-toolkit:review-pr` (and specialized reviewer agents) owns PR review agent philosophy (code-reviewer / silent-failure-hunter / security-reviewer persona prompts, diff interpretation, finding severity classification). **Do NOT re-teach.** Ship-review wraps with Layer B augmentation:

- Verify verdict pre-check (PASS required; block-on-fail).
- **Canonical docs update**: dispatched to `planner` (named teammate via SendMessage) — leverages Principle 6 Rule A continuity (shape → plan → execute → verify context). Planner holds hot context across the pitch; mechanical patching of 4 docs benefits from that context (cross-section aggregation, prose-varying README judgment).
- PR body composition is deferred to ship-final (129.3 CD-2): review records only the title + a reference. ship-final composes the full body from `shape.md` (canonical) at PR-create.
- Token cost summary + D2 knowledge candidate surfacing.

**pr-review-toolkit invocation sizing** (captain Q3 answer, Wave 6) — this is the multi-persona **code-diff** review (reads `git diff <base>..HEAD`), NOT a PR-body-prose review:
- `appetite: big-batch` → ALWAYS invoke `pr-review-toolkit:review-pr`
- `appetite: medium-batch` → OPTIONAL (entity captain-opt-in via frontmatter `pr-review-opt-in: true`)
- `appetite: small-batch` → SKIP (diff too narrow for multi-persona review to add value)

Note: ship-verify invokes atomic reviewers (`pr-review-toolkit:code-reviewer` / `silent-failure-hunter` + `ui-verify`) for diff classification during quality gating; ship-review invokes the composite `pr-review-toolkit:review-pr` for a final multi-persona **code-diff** review (code-reviewer / silent-failure-hunter / security-reviewer reading the diff `<base>..HEAD`) — a deeper second pass over the same diff, not a review of PR-body prose. The PR body does not exist at review stage (129.3 CD-2: review.md holds only a reference; ship-final composes the body). The composed body's coherence is gated separately at ship-final before `gh pr create` (ship/SKILL.md Step 6.3a).

**Rule A Fallback reminder**: when `SendMessage(planner)` for the canonical doc dispatch is unavailable (phantom team / no response) or the dispatched fresh Agent stalls, fall back per INVARIANTS Principle 6 Rule A Fallback — fresh `Agent(subagent_type: general-purpose)` with captured entity sections + doc pathspecs in the prompt. If canonical doc patches are already partially committed when a subagent stalls, check `git log` before redoing (may have landed pre-stall). Inline patching via `patch-map.sh --if-hash` is the last resort.

---

## Flow

**Phases (TaskCreate sub-tasks — inherit from /ship umbrella when pipeline-dispatched):**
`read-verify` → `dispatch-canonical-patches` → `umbrella-closeout-check` → `vcs-detect` → `pr-body-draft` → `token-summary` → `d2-surface` → `cross-review` → `emit-review.md`

### Step 1 — Read verify verdict + entity sections

Record stage-start ISO. Extract via `bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/extract-section.sh" <entity-file> <tag>`. From verify.md: `verdict.status` = `passed` or `PASS`. From execute.md: execution log (for PR body Changes section). From the resolved shape artifact (canonical `shape.md`, legacy `spec.md` fallback alias; aggregated across children): Problem, User Journey, Done Criteria, Shape Output, Size Assessment, `architecture-impact`, `product-impact`, `readme-impact`. From parent entity (if `parent:` set): `roadmap-phase`.

**Pre-check**: verdict != PASS → write `## Review Report status: blocked, reason: verify verdict <actual>, expected passed` and return. Never proceed without PASS.

**Contribution pre-review gate**: follow `_mods/contribution-contract.md` before dispatching canonical patches or reviewers. If a scoped waiver is accepted locally, preserve the exact standalone line for ship-final's PR body so generic CI evaluates the same declaration. A contract-doc-only change on an explicit inverse edge is not "docs only"; it is an incomplete coupled change unless the named row/direction waiver passes.

### Step 2 — Dispatch canonical doc patches to `planner`

SendMessage to `planner` teammate with a structured prompt. Planner already has hot context from shape + plan stages; this dispatch is the canonical-sync work, not re-discovery.

Before dispatching the planner canonical-doc patch worker or any review
cross-reviewer, render and include the shared worker-facing stewardship section:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/render-science-officer-em-stewardship-contract.sh"
```

The resulting `### Science Officer (EM) Stewardship Contract` block is part of
the assignment body. It carries results, guidelines, resources, accountability,
consequences. FO owns workflow clock, state, worktrees, dispatch mechanics, PR
lifecycle, and stage advancement. EM owns engineering judgment, delegation
quality, worker stewardship quality, risk/scope challenge, and technical
recommendations. EM does not mutate entity state, own worktrees, dispatch
workers, create or merge PRs, or advance stages. Verification is output-shape
evidence, not worker self-attestation. Review remains planner-owned
canonical-doc patch scope; EM recommendations route through FO workflow
mechanics.

### Science Officer (EM) upward report for review closeout

When review closes out verify evidence for PR readiness or canonical-doc
handoff, render and consume the shared upward report contract:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/render-science-officer-em-upward-report-contract.sh"
```

The review closeout report uses `science_officer_em_upward_report` with
`em_judgment`, `evidence_synthesis`, `risk_tradeoff_call`, `recommendation`,
`route`, `confidence`, and `fo_boundary`. `route` is one of `proceed`,
`narrow`, `return`, `block`, or `costly_no`. A status-only relay, worker
transcript summary, or checklist digest is invalid even when verify passed. The
gate is output-shape evidence, not worker self-attestation. FO owns workflow
mechanics; EM owns judgment and recommendation.

**Dispatch prompt template**:

> Draft canonical doc patches for pitch `<id>-<slug>`. Read entity children's `architecture-impact`, `product-impact`, `readme-impact` blocks + plan `canonical_doc_actions` rows + parent `roadmap-phase` + verify verdict. Aggregate per target_section. Treat `canonical_doc_actions` as the plan/verify handoff for actions discovered after shape: `source: plan` and `source: touched-files` rows can require canonical updates even when the original impact block was absent; `action: skip` rows require a `skip_rationale`. Apply patches atomically:
>
> - **ARCHITECTURE.md** — per aggregated `architecture-impact` section: `bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/patch-map.sh" --if-hash=<sha> --section=<target_section> --commit-as="docs(architecture): #<id> — <summary>" ARCHITECTURE.md`. Then append Decisions index row for #<id> via same primitive.
> - **PRODUCT.md** — per aggregated `product-impact` section: `bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/patch-map.sh" --if-hash=<sha> --section=<target_section> --commit-as="docs(product): #<id> — <summary>" PRODUCT.md`. Covers user stories, constraints, capabilities.
> - **README.md** — per `readme-impact` block: Edit tool with before/after matching (README is prose-heavy, typically NO section tags → DO NOT use patch-map.sh). Commit via explicit pathspec: `git add -- README.md && git commit -m "docs(readme): #<id> — <summary>" -- README.md`. If block has `entry_critical: true`, note it in commit body.
> - **ROADMAP.md** — status flip: `patch-map.sh --if-hash=<sha> --mode=remove-row --match=<slug> --section=now --commit-as="ship: remove #<id> from Now" ROADMAP.md` then `--mode=append --section=shipped --commit-as="ship: record #<id> in Shipped"` with new row.
>
> Discipline: read-first CAS via `--if-hash` on patch-map.sh invocations. Exit 6 (stale hash) → re-read + retry, max 3 rounds per doc. Explicit pathspec at commit-time (parallel-session staging defense). No `-a`/`-A`. Commit each doc separately.
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

Then draft `### Canonical Doc Actions Consumed` in review.md. Include one row
per plan `canonical_doc_actions` entry:

| Doc | Action Source | Plan Action | Review Outcome | Commit Or Skip Rationale |
|---|---|---|---|---|
| ARCHITECTURE.md | plan | update | updated | {commit SHA or section summary} |

Before review passes, run the executable read-only gate:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/bin/canonical-doc-sync-checker.sh" <entity-folder>
```

Any `BLOCKER canonical_doc_actions:` output blocks review. Fix by patching the
missing canonical doc outcome or by correcting the plan action / skip rationale;
do not ignore a plan-discovered update because the original shape impact block
was absent.

### Step 2.5 — Umbrella closeout check

Read `docs/ship-flow/_mods/canonical-doc-sync.md → Hook: umbrella-closeout`.

Run this check when either is true:
- current entity has `pattern: shaped-child` or `parent_pitch:`
- current entity has `pattern: pitch`, `entity_type: epic`, or `children[]`

Determine whether the current entity is the last open child by reading the parent entity's `children[]` and sibling statuses/PR states. If all siblings are shipped, merged, rejected, or explicitly deferred, the current PR owns umbrella closeout.

Closeout actions:
- `ROADMAP.md`: remove the parent umbrella row from `Now`/`Next` and append one aggregate `Shipped` row. Do not add shaped-child roadmap rows unless a child was independently listed.
- `PRODUCT.md`: patch once when the aggregate result changes a durable capability, user story, or constraint. Prefer a parent-level capability entry over per-child bullets.
- `ARCHITECTURE.md`: patch only when parent/child `architecture-impact` exists or the aggregate result changes durable architecture. Otherwise record `skipped — no architecture-impact and no durable architecture change`.

If the final child PR already merged before closeout was detected, open a small follow-up PR containing canonical doc closeout plus rule repair. Do not silently leave the parent row in `ROADMAP.md`.

Add the outcome to `## Canonical Docs Update`:

```markdown
- Umbrella closeout: yes/no — <parent id or rationale>
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

### Step 4 — Emit `## PR Draft` reference (NOT full prose) + retrospective

**Do NOT push or `gh pr create` here.** Ship-final (in `/ship` skill, Step 6.3) **composes** the PR body from `shape.md` (canonical) + verify/execute outputs at PR-create time. Ship-review only writes a SLIM `## PR Draft` to `review.md`: the **title** plus a one-line **reference** to that composition — NOT the full Problem / User Journey / DC prose.

**Why slim** (129.3 CD-2, captain gate): the full PR body changes per requirements and duplicates work ship-final does anyway. Materializing it twice (review.md draft + ship-final compose) is redundant and put review.md's full-prose restate in tension with the C15 ≤100 body cap. The body materializes ONCE, at ship-final, from `shape.md` (the canonical source per 129.1). review.md references it; it does not restate it.

`## PR Draft` template (slim):

```markdown
## PR Draft

Title: {entity title}

PR body composed by ship-final (`/ship` Step 6.3) from `shape.md` (canonical Problem / User Journey / Done Criteria) + verify UAT table + Quality Gate + execute Execution Log, materialized as the external GitHub PR body (NOT committed to ship.md). See `stages.ship.pr_payload` in entity-body-schema.yaml. Not restated here.
```

That is the whole `## PR Draft` section. Do NOT inline `## Problem` / `## User Journey` / `## Done Criteria + Verification` / `## Changes` prose — those compose at ship-final.

**`## Per-Feature Retrospective`** — review.md DOES carry this (it is genuinely-new review-stage synthesis, not reconstructable from shape.md). Keep it concise; a bounded excerpt of raw finding dumps may go in `<details>` (excluded from the ≤100 BODY cap, but the C15 2× raw-total backstop — raw ≤ 200 — still applies, so excerpt-not-dump) or reference the full set via the add-todos pointer. Required fields:

```markdown
## Per-Feature Retrospective

**Shipped this entity**: {link to entity folder / index.md}

**Deferred via `ship-flow:add-todos`** ( `/ship-flow:add-todos list` ): {N} informational + {M} critical-confidence<8 findings (counts only — the queue holds the detail).

**Risks accepted** (captain "accept-as-is" during verify CRITICAL escape, see verify.md `## ⚠️ Captain Attention`):
- [file:line] {description} → captain reasoning: {rationale}

(If none: single line "Risks accepted: none — all CRITICAL findings bounced or fixed.")

**Verify Panel Coverage**: Tier {A|B|C} · PR Quality Score {N}/10 · Adversarial: Claude {✓/✗}, Codex {✓/✗}

**What Worked**: {compact mirror — one line per captured pattern with destination tag, or "none — <reason>" or "deferred-to-debrief"}

**What Almost Failed**: {same shape — failure-mode candidates with destination tag, or "none — <reason>" or "deferred-to-debrief"}
```

Retro discipline:
- **No separate `<entity>/retro.md` file.** The retro lives in review.md (compact) and the PR body's retro section is composed by ship-final.
- **No repo `TODOS.md` path assumption.** `ship-flow:add-todos` owns deferred-finding storage; this section emits the query pointer + counts only, not the full finding list.
- Risks-accepted block populates only when verify panel triggered CRITICAL escape AND captain chose accept-as-is; otherwise the single-line "none" rendering applies.
- `## What Worked` / `## What Almost Failed` (the machine-readable Step 4.5 blocks) remain the SkillLens `[do]`/`[avoid]` source; the lines above are the compact human mirror.

### Step 4.5 — Success/Failure-mode harvest (SkillLens-derived)

Write two structured blocks to `review.md` ABOVE the `## PR Draft` section. These are `harvest-decide` skill input — keep them machine-readable. The `## Per-Feature Retrospective` block (Step 4) carries only a compact mirror for human visibility.

**S-size auto-default**: if entity frontmatter `size: S`, both blocks render the following auto-default and skip prompting:

```
Status: none

No success-mode candidates: routine S-size change; reusability-anchored capture not expected for this size class. Harvest auto-defaulted per Step 4.5.
```

The reason is ≥50 chars + reusability-anchored, so it passes Step 8 WARN gate cleanly. M/L entities require explicit captain consideration (no auto-default).

**Block format** (apply identically to `## What Worked` and `## What Almost Failed`):

````
## What Worked

Status: captured | none | deferred-to-debrief

[if Status: captured — at most 3 candidates in "What Worked", 2 in "What Almost Failed"]

1. Pattern: <short noun phrase, e.g. "early fixture parity check">
   Trigger: <when this applies, e.g. "feature changes behavior shared by multiple existing fixtures">
   Action: <executable step the future agent can perform>
   Evidence: <concrete proof — behavior preserved, artifact produced, decision shifted; cite commit SHA / DC name / file:line>
   Destination: draft-memory | promote-to-<skill>.md | one-off

[if Status: none — single line, reusability-anchored reason]

No success-mode candidates: <mechanical | one-off domain | already covered by existing canon | other reusability-anchored reason>

[if Status: deferred-to-debrief — single line]

Deferred to debrief: noticed pattern not yet ripe for codification — <one-line context>
````

`## What Almost Failed` captures **reusable failure patterns as lessons**, distinct from the incident-level findings already in verify.md / deferred-findings / risks-accepted (those are failure incidents; this is the SkillLens `[avoid]` half — pattern → trigger → action-to-take-next-time).

**Anti-garbage rules** (enforced at Step 8 gate):
- Evidence MUST cite a concrete artifact (commit SHA / DC name / file:line / failure-prevented description). Generic claims like "tests passed" fail WARN gate.
- `Destination: one-off` requires the Evidence field to make non-reusability obvious; no separate justification needed.
- Captain reviews structured blocks during Step 7 cross-review gate alongside PR body draft.

The `harvest-decide` skill (`/ship-flow:harvest-decide`) reads these blocks via section markers and records one outcome per candidate to `docs/ship-flow/success-mode-ledger.yaml`; PR body retrospective gets compact mirror lines (single line per candidate) for human visibility.

### Step 5 — Token summary

Read `token_actual` from entity frontmatter (FO-accumulated). Read `token_budget` from the resolved shape artifact (`shape.md`, with legacy `spec.md` fallback alias) Size Assessment.

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

Dispatch cross-review to `executer` teammate (reviews the slim PR Draft reference + the verify.md UAT table that ship-final will compose from + canonical-docs dispatch accuracy) or fresh sonnet (no team). Upgrade fresh **opus** when `appetite: big-batch`. The full composed PR body is gated at ship-final (Step 6.3a), not here.

**Layer A expansion per sizing rule** (see Layer A delegation section above): `appetite: big-batch` → ALWAYS invoke `Skill: pr-review-toolkit:review-pr` for a final multi-persona **code-diff** review (reads `git diff <base>..HEAD`; NOT a PR-body-prose review — the body composes at ship-final). `appetite: medium-batch` → invoke only if entity frontmatter `pr-review-opt-in: true`. `appetite: small-batch` → skip. The composed PR body's coherence is gated at ship-final (ship/SKILL.md Step 6.3a) before `gh pr create`.

7-factor rubric adapted for review stage (per INVARIANTS Principle 6 Rule C #106 T1.3 + T6.4):

1. **Feasibility** — PR size reasonable; branch ready for captain smoke?
2. **Executable scope** — review scope matches actual diff (no omitted file / no scope creep)?
3. **Quality** — no silent failures; every DC verified in UAT table; canonical commits land BEFORE PR body cites them?
4. **DC adequacy** — verify.md `### UAT` table is DC-N-keyed + reproducible (copy-paste the procedure), so ship-final's composed PR body inherits a sound DC+Verification table? (review.md no longer drafts the table — 129.3 CD-2; the source is verify.md.)
5. **Canonical sync** — 4-doc audit:
   - **ARCHITECTURE.md**: architecture-impact blocks aggregated cleanly per target_section? No section-tag corruption (patch-map.sh CAS held)?
   - **PRODUCT.md**: constraints / user stories align with shape intent?
   - **README.md**: `entry_critical` readme-impact blocks carefully applied (prose-varying needs closer audit)? Install / usage prose reads naturally?
   - **ROADMAP.md**: status flip matches pitch actual verdict? Shipped row carries correct date + PR placeholder?
6. **Reverse-audit previous stage** — does review's canonical-sync check expose a gap in verify's render-fidelity assessment? Specifically: is `render_fidelity_status` from `### Hand-off to Review` consistent with what the PR diff shows? If `affects_ui: true` and `render_fidelity_status: not-applicable`, flag for captain review.
7. **Render Fidelity + captain-ack audit trail** (T6.4, #106) — does the React rendered output match design canonical (token alignment, no fake-button, sidebar layout)? AND are all stub flags captain-acked with timestamp + decision in `## Review Report → Captain-Ack Audit`? Specifically: (a) `render_fidelity_status: fail` → VETO; (b) any `## Plan Report → Stub Flags` entry without matching captain-ack record → BLOCKING; (c) every stub flag entry must have `pre-acked-stubs: true` in frontmatter OR explicit captain rationale timestamp in Review Report.

**Reverse-audit prompt template** (T3.2 — paste verbatim into reviewer dispatch):
```
Reverse-audit: Read the entity's `### Hand-off to Review` block.
(a) Is `render_fidelity_status` consistent with the PR diff? Read `git diff <base>..HEAD -- "*.tsx" "*.css"` — any visual changes present but render_fidelity_status = "not-applicable"? (PROMPT_CAPTAIN if mismatch)
(b) Does verify.md `## Execute UAT` cover all DC types listed in plan.md `## Verification Spec`? (WARNING if gap)
(c) Are all 4 canonical docs (ARCHITECTURE / PRODUCT / README / ROADMAP) either patched with a SHA or explicitly skipped with rationale? (BLOCKING if any doc silently omitted)
(d) If this is a shaped-child or parent/epic entity, did the umbrella closeout check run per `canonical-doc-sync`? (BLOCKING if omitted)
Coaching note: render_fidelity gap here is the last catch before captain merge — enforces FM#4 and ensures ABC coaching chain is complete end-to-end.
```

Verdict: **PROCEED** / **VETO** (loop to fix sections) / **PROMPT_CAPTAIN**. Each verdict MUST include a one-sentence coaching note per INVARIANTS Rule C ABC clause.

**Circuit breaker**: if `SendMessage(executer)` is unresponsive (phantom team / timeout / fresh-Agent stall), fall back per INVARIANTS Rule A Fallback — fresh sonnet by default, fresh opus on `big-batch`. Do not block on an unresponsive reviewer.

### Step 8 — Emit review.md

Write via `bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/write-stage-artifact.sh" --stage=review --entity=<id>-<slug> --content=<draft-path>` (Wave 5 primitive at commit `acd73545`; atomic + pathspec-lock).

Review.md sections: `## PR Draft` (slim — title + ship-final composition reference, NOT full prose per 129.3 CD-2), `## Per-Feature Retrospective` (compact), `## What Worked` / `## What Almost Failed` (Step 4.5 machine-readable harvest blocks), `## Canonical Docs Update` (4 commit SHAs or skip-rationale per doc), `## D2 Knowledge Candidates` (conditional), `## Token Summary`, `## Review Report` (status / stage_cost / planner dispatch cost / Verify results / canonical sync status / timestamps / duration). Verbose finding dumps → a bounded `<details>` excerpt or the add-todos queue (keep body under the C15 ≤100 cap; `<details>` is body-excluded but the 2× raw-total backstop — raw ≤ 200 — still applies, so excerpt-and-link, don't inline-dump).

Require a `### Metrics` subsection in `## Review Report`.
Use grep-friendly `key: value` lines:
- `status:` passed | blocked
- `duration_minutes:` wall-clock minutes for review
- `iteration_count:` PR draft/canonical sync review loop count
- `canonical_docs_updated_count:` canonical docs committed
- `canonical_docs_skipped_count:` canonical docs skipped with rationale
- `pr_number:` PR number or `not-created`

**Success-mode harvest gate** (BLOCKER / WARN per Step 4.5 schema):

**Forward-only exemption check (run FIRST, before BLOCKER/WARN).** The harvest gate applies forward-only — entities created before the gate shipped (pre-0.7.0) carry no harvest blocks and MUST NOT be retroactively gated. This is enforced deterministically, not by prose. Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/check-harvest-exempt.sh" <entity-folder>/index.md
```

- Exit 0 / prints `exempt` → the entity lacks `harvest_required: true` (a pre-gate entity) → **SKIP the BLOCKER and WARN checks entirely** for this review. Record `harvest_gate: exempt (forward-only)` in `## Review Report` and proceed to PR draft.
- Exit 1 / prints `not-exempt` → the entity carries `harvest_required: true` (shaped under the gate regime; `shape-confirm.sh` stamps it at creation) → **apply the BLOCKER/WARN checks below.**

New entities are stamped automatically by `shape-confirm.sh`; the exemption needs no manual marking and no per-repo migration. (Pass the entity's `index.md` path, not the entity id/slug.)

BLOCKER on emit if (entity is `not-exempt`):
- review.md missing `## What Worked` or `## What Almost Failed` section
- Either section missing `Status:` field with one of {captured, none, deferred-to-debrief}
- `Status: captured` with >3 candidates in `## What Worked` or >2 in `## What Almost Failed`
- Any captured candidate missing one of Pattern / Trigger / Action / Evidence / Destination
- Destination not one of {draft-memory, promote-to-<skill>.md, one-off}

WARN on emit if:
- `Status: none` reason <50 chars OR effort-anchored ("ran out of time") instead of reusability-anchored
- Captured candidate Evidence is generic (no commit SHA / DC name / file:line / artifact description)
- >2 captured candidates in `## What Worked` (3 is absolute max; >2 nudges toward synthesis)

Return to /ship; advance to ship-final stage (PR creation + captain merge gate).

**Frontmatter write scope — ONLY `token_actual`.** Do NOT write `status`, `completed`, `verdict`, `pr`, `worktree` — these are FO-owned at terminal transition or pr-merge mod's concern.

### Step 8.1 — Advance entity status (frontmatter wiring)

After stage artifact lands, advance sibling `index.md` frontmatter atomically:

    INDEX_MD="<entity-folder>/index.md"
    H="$(sha256sum "$INDEX_MD" | awk '{print $1}')"
    bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/advance-stage.sh" \
      --entity="$INDEX_MD" \
      --new-status=ship \
      --stage-name=review \
      --stage-file=review.md \
      --if-hash="$H" \
      --commit-as="review(<id>): advance status to ship"

Note: `--stage-name=review` (artifact filename) but `--new-status=ship` — no `review` enum value in status field; review stage's terminal output is PR creation, so status advances to `ship`.

On exit 6 (stale hash): write `## Review Report status: blocked, reason: index.md stale hash; parallel session contaminated` and return.

---

## Invariants + red flags (STOP if violated)

- Verify verdict must be PASS. Anything else → BLOCKED, return to FO.
- Canonical docs update is dispatched to `planner` teammate — ship-review does NOT patch docs directly. Planner holds hot context; patches are mechanical + prose-sensitive for README.
- patch-map.sh `--if-hash` read-first CAS is the only safe concurrent-write pattern for ARCHITECTURE / PRODUCT / ROADMAP. Exit 6 (stale) → re-read + retry, max 3.
- README.md uses Edit tool (prose-heavy, no section tags typically); DO NOT patch-map.sh on README.
- Explicit pathspec at commit-time on every doc commit (parallel-session staging defense). No `-a`/`-A`.
- Do NOT push or `gh pr create` here — ship-final owns PR creation AND PR-body composition (from shape.md, 129.3 CD-2). review.md writes only the slim `## PR Draft` reference (title + composition pointer), never the full PR-body prose.
- Frontmatter write scope strict: only `token_actual`.
- Layer A delegation (`pr-review-toolkit:*`) owns PR review agent personas — re-teaching = Principle 6 Rule B violation.
- Cross-review VETO cap 2 rounds; round 3 → PROMPT_CAPTAIN.
- 4-doc canonical-sync audit in cross-review must cover all 4 docs (or explicit skip-rationale per doc).
- Umbrella closeout check must run for shaped-child, pitch, epic, or `children[]` entities; omission is BLOCKING.

## Circuit breakers

- Verify verdict != PASS → do not proceed; report back to FO.
- Planner reports patch-map `--if-hash` exit 6 after 3 retries on any doc → HALT, write blocked Review Report.
- Impact block schema violation (missing target_section / malformed before-after) → HALT; fix in shape stage.
- Token overrun (actual > budget × 2): note in Review Report, do not block.
- Total stage >15 min elapsed → write `review.md` partial + `⚠️ INCOMPLETE` markers + Review Report status=partial. Never exit without emitting review.md.

<!-- section:hand_off_to_ship -->
## Final Step (Hand-off): Emit Hand-off to Ship + Read Incoming Hand-off

**Read incoming**: at Step 1, read `### Hand-off to Review` from entity body. Verify `verify_verdict: passed` before proceeding. Check `canonical_docs_touched` — confirm all planned canonical doc patches landed in execute commits.

**Emit** `### Hand-off to Ship` after review.md is written:
- `pr_url`: PR URL ready for merge
- `review_verdict`: `PROCEED` verdict from cross-review gate (required for ship to proceed)
- `captain_ack_stubs`: stub flags cleared or pre-acked by captain (from Plan Report stub_flags — must be resolved)
- `roadmap_row_ready`: `true` if ROADMAP.md Now → Shipped row is prepared; `false` + reason if not
- `umbrella_closeout`: `yes/no` plus parent id or skip rationale

**No PR-create auto-merge flag.** ship-review MUST NOT pass `--auto-merge` to `gh pr create` (and the hand-off MUST NOT instruct ship-final to do so either). PR-side gating — Copilot review, branch protection, repo's post-merge automation (release-please / Fly.io / Vercel / manual / none) — owns the merge decision. After PR creation, the pr-merge mod may arm GitHub native auto-merge only through its head-bound readiness gate; Ship-Flow self-review evidence is advisory and never substitutes for required independent approval. Copilot review is allowed as a repo-side reviewer, but ship-flow does not call into Greptile / CodeRabbit / other external review services — verify panel is the self-contained quality gate.
<!-- /section:hand_off_to_ship -->

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml → stages.review` (plus `architecture-impact`, `product-impact`, `readme-impact`, `roadmap-phase` block schemas).
- Stage writer: `plugins/ship-flow/lib/write-stage-artifact.sh` (landed commit `acd73545`).
- Section extraction: `plugins/ship-flow/lib/extract-section.sh`.
- Atomic doc patches: `plugins/ship-flow/lib/patch-map.sh` (read-first CAS via `--if-hash`) — ARCHITECTURE / PRODUCT / ROADMAP only.
- Doc format rules: `plugins/ship-flow/references/doc-format.md`.
- Canonical doc timing mod: `docs/ship-flow/_mods/canonical-doc-sync.md`.
- Layer A: `pr-review-toolkit:review-pr` (PR review agent personas — ALWAYS big-batch; OPTIONAL medium-batch via `pr-review-opt-in: true`; SKIP small-batch).
- Principle 6: `plugins/ship-flow/INVARIANTS.md`.
- MEMORY: #14/#25/#37 (pathspec / staging), #30 (verification-dispatch — applies to substantial canonical-doc entries), #35 (dispatch discipline amended by Principle 6), opus-4.7-naturally-does (2026-04-23 harness diet).

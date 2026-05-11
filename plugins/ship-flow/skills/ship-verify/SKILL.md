---
name: ship-verify
description: "Use when verifying execute output before ship, including `/verify`, `/ship`, live worktree checks, UI DCs, e2e, reviewer panel, or NIT fixes. Layer A delegation: e2e-pipeline and ship-flow:ui-verify own UI DC verification; reviewer personas own haiku review."
user-invocable: true
argument-hint: "<entity-id> [--fast | --full]"
---

# Ship-Verify — VERIFY Stage (2.0)

You run VERIFY. Output: `docs/<wf>/<id>-<slug>/verify.md`. **You are NOT the author of the code** — review as an independent agent. PASS advances to review; FAIL feeds back to execute (max 2 rounds).

**Three concerns, one stage**: Quality (mechanical gate on touched surfaces) + Review (classified findings from dispatched haiku reviewers) + UAT (done-criteria evidence review + spot-check).

## Boot Self-Check

Run before any verify work. Stop and SendMessage(FO) if any check fails.

1. **Entity status**: read entity frontmatter `status:` — must be `execute`. If still `plan` → execute not done; if `verify` → verify already ran (check for re-entry / feedback round).
2. **execute.md present**: `<entity-folder>/execute.md` exists and has `## Execute UAT` section. If absent → SendMessage(FO): "execute.md missing — cannot verify without execute evidence."
3. **Hand-off to Verify present**: entity body contains `### Hand-off to Verify` block. If absent → SendMessage(FO): "Missing Hand-off to Verify — executer did not complete handoff."
4. **Git state**: `git log --oneline -1` matches expected execute commits. If HEAD is older than execute stage → stale worktree, surface before proceeding.
5. **Dev server** (if `affects_ui: true`): invoke `worktree-dev-server` check — port responsive before running UI-type DCs.
6. **Density-aware skill load** (T3.4): read `answers_density` from entity frontmatter. `high` → auto-load framework skills per ship-runtime-detect Step R6; skip FO ask. `low|vacuum` → SendMessage(FO) with proposed skill list; wait for confirmation.

## Layer A delegation (Principle 6 Rule B)

`e2e-pipeline:e2e-test`, `e2e-pipeline:e2e-walkthrough`, and `ship-flow:ui-verify` own agent-browser UI-DC verification (flow execution, walkthrough recording, computed-style regression). `pr-review-toolkit:code-reviewer` / `pr-review-toolkit:silent-failure-hunter` / `trailofbits:*` / `comment-analyzer` / `code-simplifier` / `pr-test-analyzer` / `type-design-analyzer` own haiku reviewer personas when installed. **Do NOT re-teach.** If pr-review-toolkit is unavailable, fallback to `ship-flow:verify-reviewer-panel` for the general external reviewer, silent-failure-reviewer, and domain-expert-reviewer lenses. Ship-verify wraps with Layer B augmentation:

- ROI-aware scoped quality gate (touched-surfaces-only when changed-LOC stays under threshold).
- Classified findings (BLOCKING / WARNING / NIT) + auto-fix NITs inline.
- Spot-check critical DCs with declarative e2e YAML when available; fall back to `curl -sfN` + `grep` for UI-type DCs.
- Cross-review gate (5-factor rubric: feasibility / executable scope / quality / DC adequacy / canonical sync) with fresh-subagent fallback per Principle 6 Rule A.

---

## When to use

- **Pipeline** (invoked by `/ship`) — dispatched via SendMessage to `verifier` teammate; cross-review gate mandatory; produces `verify.md`.
- **Standalone** `/verify <entity-id>` — user-invocable. Reuses `pitch-<id>` team if it exists; else creates fresh `verify-<pitch-id>` team with opus verifier.
- **Standalone** `/verify "<requirement>"` — treat as concrete-requirement entry; inverse-escape if vague (see `/ship` pattern).
- `--fast` — skip cross-review gate (captain manual fast-feedback). `--full` — force full re-run of every DC (skip spot-check heuristic).

**Inverse escape:** entity-id with no matching `docs/<wf>/<id>-*/` or `docs/<wf>/<id>-*.md` → announce `entity not found — run /shape <directive>` and EXIT.

---

## Step 1 — Resolve entity + team + TaskCreate

Resolve `WORKFLOW_DIR` from `docs/*/README.md` frontmatter `entry-point:`. Read entity file (flat `.md` or folder `index.md` + prior `.md` stages). Record stage-start ISO timestamp.

**Read** (tag-based via `bash plugins/ship-flow/lib/extract-section.sh <entity> <tag>`):
- resolved shape artifact (`shape.md`, with legacy `spec.md` fallback alias, or entity `## Sharp Output`) → `### Done Criteria`, `### Size Assessment`
- `plan.md` → `### Plan` (`files_modified`), `### Verification Spec` (DC procedures)
- `execute.md` → `### Execution Log` (commit SHAs, base SHA), `### Issues Found`, `## Execute UAT`
- `PRODUCT.md` → `## Constraints` (if exists)
- `ARCHITECTURE.md` → relevant sections when plan `canonical_doc_actions`,
  touched files, or design/spec impact indicate schema/API/domain/data-flow,
  storage, runtime, or component-boundary change

Capture **execute base SHA** from first task's parent commit in `execute.md`. Do NOT recompute from `main..HEAD` (MEMORY #25 — parallel-session churn produces reverse-subtraction artifacts).

**Pre-check**: if > 50% of execute tasks failed → write `verify.md` with `status: blocked`, notify captain, EXIT. Never exit without the artifact.

### Verification Claim records

Use repeatable claim records for verdict-bearing evidence. Place each record under the subsection that owns the evidence being judged: `### Quality Gate`, `### Review Findings`, or `### UAT`. A required claim record is mandatory when accepting or rejecting a Done Criterion, acceptance criterion, captain UAT finding, blocking reviewer finding, runtime/API/UI/e2e spot-check, new contract smoke, or quality-gate result that determines the final verify verdict. Advisory format checks, repeated child rows covered by a named parent claim, and non-blocking notes may omit local records only when the omission is explicit.

```markdown
#### Verification Claim: <short falsifiable claim>

| Field | Value |
|---|---|
| claim_source | `<DC-N | quality-gate:<check> | review:<lens> | captain-uat | other:<source>>` |
| condition | <state under which the claim must hold> |
| metric_or_observable | <number, output, screenshot, response, reviewer finding, or test behavior> |
| threshold | <pass threshold, exact expected artifact, or "not applicable: <reason>"> |
| smallest_disproving_surface | <test, CLI transcript, browser trace, HTTP response, screenshot, profile, reviewer citation, or file diff> |
| baseline | <artifact/command/result or "not applicable: <reason>"> |
| treatment | <artifact/command/result from current implementation> |
| comparison | <delta or exact comparison, including known confounds> |
| verdict | `VERIFIED` \| `NOT VERIFIED` \| `INCONCLUSIVE` |
| route_to | `proceed` \| `execute` \| `design` \| `plan` \| `captain` \| `follow-up` |
```

Verdict dominance:
- `NOT VERIFIED` on any required claim becomes `VETO` and routes to `execute`, unless the record proves missing or contradictory plan/design intent; then route to `plan` or `design`.
- `INCONCLUSIVE` on a required claim becomes `PROMPT_CAPTAIN` when valid evidence cannot be gathered after the required preflight or comparison attempt. It becomes `VETO` when caused by implementation-owned missing artifacts, broken runtime, or invalid execute evidence.
- `INCONCLUSIVE` on an advisory claim may still allow `PROCEED` only when the record uses `route_to: follow-up`, explains why the claim is not acceptance-critical, and no required claim is `NOT VERIFIED` or `INCONCLUSIVE`.
- `VERIFIED` supports `PROCEED` only when all required claim records are verified and existing quality, review, and UAT gates also pass.

**Team** (Principle 6 Rule A):
- Pipeline invocation → already inside `verifier` teammate context. Inherit parent `/ship` umbrella tasks (no new TaskCreate).
- Standalone — team `pitch-<id>` exists → SendMessage to `verifier`. No team exists → `TeamCreate(team_name: "verify-<pitch-id>", members: ["verifier"])` + spawn opus verifier.
- Standalone — TaskCreate 3 sub-tasks: `scoped-gate` → `spot-check-uat` → `escalation-or-nits`.

---

## Step 2 — Quality gate (scoped, ROI-default)

**Rule**: run quality checks ONLY on runtime surfaces execute wrote commits to. Full-project checks on untouched surfaces are baseline noise (MEMORY #10 generalized). Invoke `ship-flow:ship-runtime-detect` to populate `{commands.test/build/typecheck/lint}`.

Before dispatching parallel checks, emit `verify-check-manifest` with rows for tests, lint/typecheck/build, `ship-flow:ui-verify`, `ship-flow:verify-reviewer-panel` review lenses, low-model domain reviewers, domain/schema review, and static/security reviewers when applicable. Read plan task `reviewer_questions` and `### Hand-off to Execute → domain_acceptance_checklist`; each checklist row becomes a `review_lenses` row with the same `Verify Lens`, `Reviewer Question`, affected path family, required skills, and evidence requirement. Also materialize any task-level reviewer_questions that are not already represented in `domain_acceptance_checklist`, including framework-only prompts, into `review_lenses` rows with source `task.reviewer_questions`. Concrete lenses such as `project-db`, `fmodel`, or `refine-gotchas` map to the `domain-expert-reviewer` reviewer kind while preserving the concrete lens name in `Lens`. Each row records input, owner, whether it can run in parallel, and required evidence. The verifier is the single integrator: parallel checks may gather evidence concurrently, but only the verifier classifies findings and writes the final verdict.

When plan contains routed domain context, verify must first run
`bash plugins/ship-flow/lib/extract-section.sh <plan.md> context-routing-manifest`
and treat an empty result as BLOCKING with `route_to: execute` or `plan`
depending on whether execute omitted evidence or plan omitted the block. The
extracted `context-routing-manifest` is the only accepted input for routed
obligations; prose-only inference is not valid evidence. Every manifest
`required_skills` row must become a `review_lenses` row, a baseline quality
check, or an explicit skip rationale. Record manifest-derived rows with source
`context-routing-manifest`, the extracted block as input, and a
`manifest_required_skill` evidence note when the row comes from
`required_skills`.

The general external reviewer baseline always runs for source diffs. It reviews the execute diff as a non-author against `plan.md`, `design.md`, execute hand-off, and changed files. Use `pr-review-toolkit:code-reviewer` when installed; otherwise use `ship-flow:verify-reviewer-panel` lens `general-external-reviewer`.

The silent failure reviewer baseline always runs alongside the general external reviewer for source diffs. Use `pr-review-toolkit:silent-failure-hunter` when installed; otherwise use `ship-flow:verify-reviewer-panel` lens `silent-failure-reviewer`.

Domain expert panel checks are read-only and findings-only. For each matched domain or adopter file-signal lane, dispatch a low-model reviewer with the correct worktree path, base/head diff range, touched files, domain lens, and required skills/knowledge modules. The prompt MUST say "do not edit files" and require `file:line` citations. Discard outputs from the wrong worktree, wrong base/head, or uncited claims before classification.

Every low-model domain reviewer must self-check repo path, branch, base/head, and changed files before reviewing. If any value does not match the verifier's
manifest, the reviewer returns `INVALID_CONTEXT` and the verifier drops the
result. For valid reviewers, write a domain-lens matrix in `verify.md` with
columns `Lens`, `Reviewer`, `Finding`, `Severity`, `Evidence`, and
`Disposition`. Use severity values Critical/Important/Minor; Critical and
Important findings must be fixed before verify PASS, while Minor findings may
defer only with an explicit reason and follow-up route.

**Per-surface commit count**:
```bash
for SURFACE in $SURFACES; do
  N=$(git log {execute_base}..HEAD --oneline -- "$SURFACE" 2>/dev/null | wc -l)
  # N == 0 → scoped PASS (documented baseline), skip
  # N > 0  → run full checks on that surface
done
```

Run checks 1-4 (tests / lint / typecheck / build) on surfaces with `N > 0`. Check 5 (format) advisory only. Capture last 40 lines per check as evidence.

For each verdict-bearing quality result, write or reference a claim record in `### Quality Gate`. The record must identify the checked surface, command, threshold, smallest disproving output, and final `VERIFIED` / `NOT VERIFIED` / `INCONCLUSIVE` result. A verdict-bearing quality failure without a claim record is incomplete verify evidence.

**Any check FAIL → feedback to execute.** Do NOT proceed to review. Max 2 feedback rounds, then PROMPT_CAPTAIN.

### Step 2.1 — TDD Evidence Audit

Invoke `ship-flow:test-driven-development` as the audit contract. `superpowers:test-driven-development` may improve local discipline when available, but verify must not assume adopters have it installed.

For every plan task that is not marked `TDD: skip -- <reason>`:
1. Read the task `tdd_contract` from `plan.md`.
2. Read execute evidence for `RED command`, `Expected RED failure`, `GREEN command`, and `REFACTOR check` / `refactor_check`.
3. Confirm RED-before-GREEN ordering: the RED command ran before production edits were accepted, failed for the expected reason, then GREEN passed after implementation.
4. If RED evidence is absent, RED passed immediately, or GREEN exists without matching RED, emit a `BLOCKING` finding with `route_to: execute` and required fix: rerun/rework the task with valid RED-before-GREEN evidence or bounce to plan if the contract was underspecified.

Record results inside existing `### Review Findings` in `verify.md` under subsection `#### TDD Evidence Audit`, using the schema-backed severity vocabulary `BLOCKING`, `WARNING`, or `NIT`. Use columns `Task`, `RED evidence`, `GREEN evidence`, `REFACTOR check`, `Severity`, and `route_to`.

When TDD Evidence Audit changes the verify outcome, add a claim record under `### Review Findings`: missing or invalid RED-before-GREEN evidence is a verdict-bearing quality/review claim with `claim_source` `quality-gate:tdd-evidence-audit` and `route_to: execute`.

### Step 2.2 — Per-error diff-aware attribution (ROI critical)

**Trigger**: any check output contains `file:line` references.

Surface-level scoping says "execute didn't touch surface X → failures are pre-existing". Necessary but not sufficient — a touched surface can mix execute-introduced + pre-existing errors. Attribute **per error**:

1. Parse `file:line`. Run `git diff --name-only {execute_base}..HEAD -- <file>`; empty → pre-existing on this file.
2. File touched → `git blame -L<line>,<line> --show-name HEAD -- <file>`; extract SHA.
3. SHA ∈ `{execute_base}..HEAD`? **Yes** → execute-introduced (real failure: auto-fix per Step 5 or feedback-to-execute). **No** → pre-existing line; note but don't block.

**Forbidden rationalization**: "pattern existed elsewhere before" does NOT justify skip. Attribution is per-file, per-line. Precedent: entity #078 — 2 Principle 5a ERRORs blame-attributed to execute's report commit, mis-classified as "pre-existing pattern", CI failed on PR.

**Record in `### Quality Gate`**: which surfaces were scoped + each pre-existing error suffixed `(pre-existing baseline)`.

---

## Step 3 — Review (haiku reviewer matrix + spot-check)

**Reviewer matrix (Principle 3)**: default 2 reviewer lenses for source-file diffs; skip haiku dispatch entirely for non-source-only diffs.

```bash
DIFF_FILES=$(git diff {execute_base}..HEAD --name-only)
SOURCE_FILES=$(echo "$DIFF_FILES" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|rb|go|rs|java|kt|swift|c|cc|cpp|h|hpp|cs|php|ex|exs|sh)$')
```

| Diff content | Haiku dispatches | Notes |
|---|---|---|
| Non-source only (docs / SKILL.md / config) | **0** — sonnet inline review on diff | 2026-04 D1: haiku hallucinate 50-100% on prompt-text diffs |
| S/M/L with source | `pr-review-toolkit:code-reviewer` + `pr-review-toolkit:silent-failure-hunter`; fallback `ship-flow:verify-reviewer-panel` lenses `general-external-reviewer` + `silent-failure-reviewer` | Default pair |
| Opt-in via `haiku-opt-in: <name>` | `trailofbits:{insecure-defaults \| sharp-edges \| variant-analysis}`, `pr-review-toolkit:{pr-test-analyzer \| type-design-analyzer \| comment-analyzer \| code-simplifier}` | Explicit tag only |

Cost: ~$0.05/haiku. Default M/L = $0.10.

**Inline pre-scan (always, before haiku findings arrive)**:
1. **Stale references** — for every symbol removed, grep remaining refs outside the diff.
2. **Plan consistency** — cross-check `git diff --stat` vs `plan.md → files_modified`. Unplanned change OR missed task = finding.
3. **Constraint check** — `PRODUCT.md → ## Constraints` respected?
4. **Canonical drift check** — read plan `canonical_doc_actions` and changed
   files. If source changes touch schema/API/domain/data-flow/storage/runtime or
   component-boundary files, compare the diff against relevant
   `ARCHITECTURE.md` sections and the plan's action rows. Missing
   `canonical_doc_actions`, stale architecture contract, or an `action: skip`
   without `skip_rationale` is a WARNING with `route_to: review` when the code
   is otherwise correct, or BLOCKING with `route_to: plan` when the verification
   criteria are underspecified. If product constraints are violated, route to
   execute or design depending on whether implementation or design intent is at
   fault.
5. **CLAUDE.md walk** — for each changed file, walk dirname to repo root collecting `CLAUDE.md`; check each rule against the diff. Severity: "must/never/always" → BLOCKING; "prefer/should/consider" → WARNING. Dedup + cache during walk.
6. **Folder guidance receipt gate** — for each execute-touched file group, run `bash plugins/ship-flow/lib/check-guidance-receipt.sh --config=.claude/ship-flow/skill-routing.yaml --files=<changed-files> --artifact=<entity-folder>/execute.md`. Exit 12 is BLOCKING: execute did not prove it read non-root app-folder `AGENTS.md`/`CLAUDE.md` or did not load routed/folder skills. Do not treat root `AGENTS.md`/`CLAUDE.md` absence as failure; the resolver's `codex_context_boundary` deliberately avoids duplicating Codex session behavior.

**Spot-check haiku citations — 100%, not a sample** (MEMORY #078 precedent):
- Read exact file at cited line ±2 lines.
- Content matches → keep. Line shifted but content within ±5 → keep with updated line. Content absent → DROP + log `[D2-candidate] {agent} hallucinated at {file}:{line}` in `### Knowledge Captures`.
- Single agent > 30% hallucination → discard ALL findings from that agent for this review; log as untrusted for this diff class.

**Classify surviving findings**:
- **BLOCKING** (security / broken / data-loss) → feedback to execute (max 2 rounds).
- **WARNING** (potential bug / weak edge case) → log; proceed if no BLOCKING.
- **NIT** (style / minor) → consider auto-fix per Step 5.

BLOCKING findings require a claim record under `### Review Findings` naming the reviewer lens, cited surface, threshold, comparison, verdict, and route. WARNING findings also require a claim record when verify allows them not to block; the record must explain why the claim is advisory or why `route_to: follow-up` is acceptable.

### Severity-disagreement aggregation

When the default haiku pair (`code-reviewer` + `silent-failure-hunter`) both return findings, aggregate using **FAIL > WARN > PASS** (strict dominance):

| Reviewer A | Reviewer B | Aggregate |
|---|---|---|
| BLOCKING | any | BLOCKING |
| WARNING | BLOCKING | BLOCKING |
| WARNING | WARNING | WARNING |
| WARNING | NIT or PASS | WARNING |
| NIT | NIT or PASS | NIT |
| PASS | PASS | PASS |

At the verdict-mapping layer (Step 5 cross-review gate): **PROMPT_CAPTAIN > VETO > PROCEED** — the worse verdict wins.

**Note**: Spec 101.3 originally framed PAR as adding a 2nd reviewer to the baseline. Current ship-verify SKILL.md already runs the default haiku pair unconditionally on source diffs (the pair IS the baseline). This section codifies the aggregation rule that was previously implicit; reviewer count unchanged. See `docs/ship-flow/101-density-aware-autonomy/plan.md` D1 for cross-review adjudication record.

**Density-aware gate**: the above aggregation is unconditional (Path X). On `density:high` entities, verdict-flip for PROMPT_CAPTAIN is handled downstream in `ship/SKILL.md → Verdict-flip transformation` (101.2 territory), NOT at reviewer dispatch level.


---

## Step 3.5 — Designer ui-verify (conditional)

**Trigger**: entity body contains `## Design Output` OR entity folder contains `design.md`.

**Why named teammate, not fresh haiku**: designer@pitch-XX holds full design-context continuity (Principle 6 Rule A). Haiku has no context on captain Q-loop decisions (D1-D6) or category-specific rationale. A fresh subagent would re-derive from scratch; named teammate catches regressions against decisions already made.

**Dispatch**:
```
SendMessage(to: "designer@pitch-XX",
  body: "UI-verify requested for <entity-id>. Attach execute diff + design artifacts.
  Execute diff: git diff <execute_base>..HEAD -- <ui_files>
  Design reference: <entity-folder>/design.md (or plugins/<app>/design/)
  Return findings as: BLOCKING / WARN / NIT with file:line citations.")
```

**Designer findings integration**:
- Append designer findings to `### Review Findings` in `verify.md` under subsection `#### Design Parity`.
- Apply same classify/spot-check rules as haiku findings: drop hallucinated citations (>30% → discard agent).
- BLOCKING design-parity finding → run Step 3.6.5 Design Feedback Router and feed back to the routed stage (design or execute; counts toward that stage's 2-round max).
- WARN → log; does NOT block advance if no other BLOCKING.

**Skip when**:
- Entity `affects_ui: false` AND no `## Design Output` in entity body AND no `design.md` in entity folder.
- Captain explicitly marks `designer-verify: skip` in verify.md frontmatter.

---

## Step 3.6 — fragment-level ui-verify mechanical check (forced when affects_ui)

**Why this is separate from Step 3.5**: Step 3.5 dispatches designer teammate (LLM) to read source diff against design artifacts. LLM reading CSS/JSX source has weak intuition for **rendered computed style** — cascade specificity, Tailwind v4 `@theme` indirection, flex-shrink, margin-collapse all resolve at render time, not parse time. `var(--primary)` in source and hardcoded `#3b82f6` in source can both look correct to LLM yet produce different rendered values. Step 3.6 closes the LLM-vs-rendered gap by invoking the `ui-verify` skill (headless browser computed-style probe).

**Trigger** (G14, 2026-04-29 disambiguation): entity `affects_ui: true` AND `### Hand-off to Plan` block lacks `design-skipped: true` AND contains `render_fidelity_targets[]` with ≥1 entry. (`design-skipped: true` short-circuits past Step 3.6; absence of hand-off block entirely is already BLOCKED at plan Step 1.6, so verify can assume the block is well-formed when it reaches here.)

**Dispatch**:

1. Generate ui-verify YAML spec from entity hand-off:
   ```bash
   bash plugins/ship-flow/lib/generate-ui-verify-spec.sh <entity-folder> <mapping-name> [auth-account] \
     > .claude/e2e/ui-verify/<entity-slug>.yaml
   ```
   `<mapping-name>` is the e2e-pipeline mapping filename without `.yaml` (e.g., `spacebridge`). The script reads `render_fidelity_targets[]` from the entity's `### Hand-off to Plan`, converts each to a ui-verify check (kebab→camel CSS property names, D{N} backref preserved in check name).

2. Invoke ui-verify against the generated spec:
   ```
   Skill: ship-flow:ui-verify
     YAML: .claude/e2e/ui-verify/<entity-slug>.yaml
   ```

ship-flow:ui-verify drives a real browser via `agent-browser`, runs `getComputedStyle()` per check, and emits PASS/FAIL with a report. Pixel-diff baseline (when present at `plugins/<app>/design/baseline/<component>.png`) is checked separately by whole-page visual parity Step 3.6.1; fragment-level ui-verify remains selector/value evidence.

**ui-verify findings integration**:
- Append to `### Review Findings` in `verify.md` under subsection `#### Mechanical UI Parity`.
- Token-resolution mismatch (computed value differs from tokens.css declaration) → **BLOCKING**.
- Pixel-diff exceeds 1% but token resolution OK → WARN (often CSS reset / font-load timing — designer teammate reviews in 3.5).
- Baseline screenshot missing for cited specimen → **BLOCKING** (designer should have emitted baseline at Phase 7 captain confirm — route_to: design).

**Skip when**:
- Entity `affects_ui: false` (skipped by trigger).
- `### Hand-off to Plan` absent OR `render_fidelity_targets[]` empty (no DCs to mechanically check).
- `ui-verify` skill not installed → emit WARN `ui-verify unavailable` in `verify.md`; do NOT silently skip — captain must see the gap.

**Why not fold into Step 3.5**: 3.5 owns semantic review (D1-D6 captain decisions, designer hot context). 3.6 owns mechanical assertion (computed-style equality, pixel diff). Different failure modes, different tools, different reviewers — folding loses the distinction and lets LLM rationalize past rendered-value mismatches that are categorically not a judgment call.

### Step 3.6.1 — Whole-page visual parity

Fragment-level ui-verify is not a whole-screen approval. A page can satisfy
selector/token assertions while still diverging from the composed design because
layout rhythm, density, hierarchy, whitespace, or surrounding shell changed.

**Trigger**: entity `affects_ui: true` AND `### Hand-off to Plan` contains
`whole_page_visual_targets[]` with ≥1 item. If design emits
`render_fidelity_targets[]` but omits `whole_page_visual_targets[]`, record WARN
`whole-page visual parity unavailable — design handoff only provided fragments`
and route_to `design` unless captain explicitly marked the UI as component-only.

**Dispatch**:

1. Start or reuse the live worktree dev server from Step 4.0.
2. For each target, open `route`, capture a full-page screenshot, and compare it
   to `reference_artifact`:
   - If `reference_artifact` is an HTML mockup, open/capture it at the same
     viewport before comparing.
   - If `reference_artifact` is an image, compare directly.
   - If no automated screenshot diff primitive is available, run
     `e2e-pipeline:e2e-walkthrough` or `agent-browser` screenshot capture and
     dispatch designer/verifier visual review with both images attached.
3. Record `threshold` from the target. Default threshold is WARN above 1%
   meaningful visual delta and BLOCK when the primary composition does not
   match the design intent, even if fragment-level ui-verify passed.

**Findings integration**:
- Append to `### Review Findings` under `#### Whole-page Visual Parity`.
- `fragment ui-verify: PASS` and `whole-page visual parity: FAIL` is a real
  BLOCKING mismatch. Route to `execute` if implementation drifted; route to
  `design` if the design reference was incomplete or stale.
- Verify report must include the runtime screenshot path and the reference
  artifact path. Captain visual smoke remains final acceptance, not the first
  whole-page check.

### Step 3.6.5 — Design Feedback Router

Run this router for every BLOCKING or WARN finding from `#### Design Parity`,
`#### Mechanical UI Parity`, and `## Intent Match Findings` before issuing a
feedback request. The route is part of the finding record:

```markdown
| Severity | Finding | Evidence | route_to | route_reason |
|---|---|---|---|---|
| BLOCKING/WARN/NIT | <specific mismatch> | <file:line, command, or artifact> | design/execute | <why> |
```

Routing table:

| Finding class | Route |
|---|---|
| semantic design gap, information architecture mismatch, unclear affordance, missing state model, contradictory captain decision, incomplete `design_constraints[]`, missing baseline artifact, impossible-to-judge design intent | `route_to: design` |
| implementation drift from clear design intent, runtime behavior mismatch, computed token mismatch caused by changed code, DOM/a11y role mismatch, API/schema implementation not matching typed design output | `route_to: execute` |
| ambiguous ownership after reading design + execute evidence | `route_to: design` first, because execute cannot be judged fairly until intent is complete |

Feedback actions:
- `route_to: design` → SendMessage to `designer@pitch-XX` with the finding,
  evidence, and requested correction to `design.md` / design artifacts /
  handoff constraints. Do not ask executer to guess design intent.
- `route_to: execute` → feedback to executer with the exact violated
  constraint and evidence.
- Mixed findings split by route; do not collapse the batch to execute merely
  because at least one implementation bug exists.

This router is the verify-stage counterpart to ship-design's visible UI handoff:
review/verify can repair missing or ambiguous design intent instead of forcing
the execute worker to absorb design-stage omissions.

### Step 3.6.6 — Captain UAT Feedback Router

Run this router when the captain performs manual UAT during the verify stage and
reports a finding before verify is passed. This is **verify-stage captain UAT
feedback**, not post-ship captain smoke. It stays inside the current stage loop.

Record all incoming captain findings in `verify.md` under
`## Captain UAT Feedback` before acting:

```markdown
## Captain UAT Feedback

| Severity | Finding | Evidence | route_to | owner | action |
|---|---|---|---|---|---|
| BLOCKING/WARNING/NIT | <captain finding> | <screenshot, route, command, or quote> | execute/design/plan/follow-up | <owner> | <SendMessage or todo> |
```

Routing table:

| Finding class | route_to | owner |
|---|---|---|
| implementation or runtime behavior violates clear plan/design/DC | `route_to: execute` | `executer@pitch-XX` |
| semantic UX, information architecture, visual hierarchy, state model, affordance, or design contract is incomplete/contradictory | `route_to: design` | `designer@pitch-XX` |
| task split, acceptance criteria, or verification spec omitted required work | `route_to: plan` | `planner@pitch-XX` |
| pre-existing bug or genuinely new request outside this entity | `route_to: follow-up` | `/add-todos` or `/shape` |

Owners: `executer@pitch-XX`, `designer@pitch-XX`, and `planner@pitch-XX`
receive routed feedback for execute/design/plan ownership respectively.

For `BLOCKING` or `WARNING`, the FO MUST NOT inline-fix the issue. SendMessage
to the owning teammate with the captain finding, evidence, affected route/files,
and required artifact update. If the named teammate is unavailable, use the
documented Principle 6 Rule A fallback fresh worker with the same owner role and
captured context; do not silently self-assign the patch.

Inline fix is allowed only for `NIT` findings that are mechanical, <=5 LOC, and
have no semantic, UX, logic, data, routing, or contract judgment. NIT inline
exception: NIT, mechanical, <=5 LOC, no semantic judgment. All other
captain UAT feedback remains routed feedback, even when the FO knows the likely
fix.

### Step 3.7 — Intent-match verifier (schema-domain ad-hoc hook)

**Trigger**: run when any of these are true:
- Entity frontmatter has `domain: schema`.
- `bash plugins/ship-flow/lib/registry-resolve.sh --classify <entity spec/index>` resolves or partially resolves to `schema`.
- The entity has a design artifact (`design.md` or entity body design output) containing `## Schema Design Output`.

**Registry contract**: verify is a registry consumer. Before checking schema intent, run:

```bash
bash plugins/ship-flow/lib/registry-resolve.sh --validate --domain=schema
bash plugins/ship-flow/lib/registry-resolve.sh --domain=schema
```

Respect M1-M5 degradation from Principle 9. Do not hardcode domain-to-specialist mappings inside ship-verify prose; the registry owns specialist and knowledge-module resolution.

**Source contract**: `## Schema Design Output` is the source of truth. Build an intent checklist from the typed output and explicit handoff constraints:
- L1/L2/L3 relationship intent, including any required denormalized projections.
- event-saga behavior and sequencing requirements.
- RBAC read/write boundaries.
- fstore rebuild and backfill requirements.
- Explicit "handoff constraints" or "must-not" notes in the schema design output.

**Comparison**: compare execute evidence or diff against the design intent checklist.
- Use `git diff <execute_base>..HEAD -- <schema/API/migration files>` for structural drift.
- Use `execute.md -> ## Execute UAT` for evidence drift.
- If a checklist item has no corresponding changed file, command evidence, or explicit execute note, treat it as unresolved intent.
- If execute intentionally changed the intent, require an explicit design-stage note or captain decision; otherwise it is drift.

**Output format**: when drift is found, append a top-level block to `verify.md`:

```markdown
## Intent Match Findings

| Severity | Finding | Evidence | route_to |
|---|---|---|---|
| BLOCKING/WARN/NIT | <specific design-vs-execute mismatch> | <file:line, command, or artifact citation> | design/execute |
```

Use `route_to: design` when the design intent is incomplete, contradicted, impossible to execute, or missing enough detail for execute to be judged fairly. Use `route_to: execute` when the design intent is clear and execute drifted from it; otherwise route to execute. These findings integrate into `### Review Findings` classification: BLOCKING feeds back to the routed stage, WARN logs but does not block if no other BLOCKING finding exists, and NIT can be auto-fixed only if it is mechanical artifact cleanup.

**Boundary**: this is the first ad-hoc verifier for X1/113.4. Do not create a new `intent-match-verifier` stage skill and do not add default haiku fan-out. X2 owns typed contract-registry dispatch for multiple verifier types.

---

## Step 4 — UAT (spot-check default, full re-run fallback)

**Default**: spot-check ≤2 critical DCs + evidence review (full re-run is fallback). 2026-04 D1: n=31 DCs, 0 verdict changes on full re-run.

**Runtime mandate** (carlove SEC-10/15 retro, 2026-04-26): DC re-runs in 4.2/4.3/4.4 MUST execute against a **live runtime** — worktree dev server up + API reachable + browser able to load route. Artifact-only verification (compiled script, type-check, unit tests) is **insufficient**: 4 critical bugs slipped past artifact-green verify on SEC-10 #574 + SEC-15 #573, caught by reviewers in 4 minutes.

### 4.0 — Runtime preflight (hard gate — runs before 4.1)

No DC may be marked PASS via a runtime path until preflight succeeds:

1. **Dev server up** — `Skill: "worktree-dev-server"` (project-level skill convention; adopters host their own boot helper under that name). MUST report reachable port per surface in `plan.md → files_modified`.
2. **API reachable** (router / contract touched) — `curl -sfN <api>/<liveness>` → HTTP 2xx; capture status + body excerpt.
3. **Browser loads route** (UI-type DC) — `curl -sfN <ui-route> | head -200` returns rendered shell.

| Preflight outcome | Action |
|---|---|
| All required steps green | Proceed to 4.1 / 4.2 |
| Dev server fails (port conflict / missing migrations / env / deps) | **BLOCKER.** Write `verify.md` `status: blocked, reason: dev server unavailable — <cause>` + PROMPT_CAPTAIN. Do NOT route around with `API offline → conditional pass`, `artifact-only`, or `visual verification skipped`. |
| API / browser probe fails post-boot | Treat as real DC failure → feedback to execute (max 2 rounds). |

**Anti-pattern** (Pilot Wave 1): verifier logged `DC-3 conditional (unit coverage verified, API offline)` and advanced to PASS — compiled artifact existed; API never hit; contract-shape bug caught by reviewers in 4 minutes. **Conditional-pass on missing runtime = verifier bug**, not an escape hatch.

Record commands + outputs in `### Runtime Verification` (template in Step 6).

### 4.1 — Evidence review

Read `execute.md → ## Execute UAT` (or `## Execute Output → ### Done Criteria Verification` for legacy). Each row must have:
- Procedure from `plan.md → ### Verification Spec`
- Concrete evidence (command output excerpt / file:line citation / screenshot path) — not just "✅"

Each sampled, re-run, or trusted DC used to pass or fail acceptance must have a local claim record in `### UAT` or explicitly name the parent claim record covering that row. The claim record is required even when the verifier trusts execute evidence rather than re-running the procedure.

**Degrade to 4.3 full re-run if**: evidence missing, only "ok"/"pass"/"✅", procedure differs from Verification Spec, OR ≥1 DC marked FAIL/degraded without explanation.

### 4.2 — Spot-check

Pick 2 DCs: (1) **highest-risk** (priority `e2e > api > ui > cli > skill`; ties by assertion complexity), (2) **random** from remaining. **All primitives below execute against the live runtime from Step 4.0; unit-test path alone does NOT satisfy spot-check**:

| Type | Primitive (runtime-mandatory) |
|---|---|
| `cli` | Bash: command + exit code + output grep |
| `api` | `curl -sfN <api>/<endpoint>` on live server + status + JSON shape assertion. Unit/contract tests alone insufficient (SEC-15 V1: static type-check OK, runtime `lt` returned 400). |
| `ui` | `curl -sfN <route> \| grep <assertion>` (MEMORY turbopack-streaming — `-N` mandatory for Next.js 16). Flow present → `Skill: e2e-pipeline:e2e-test` (live server, NOT compile-only). |
| `skill` | `Skill("<name>")` with probe prompt, check output shape |
| `e2e` | `Skill: e2e-pipeline:e2e-test` actually runs `npx playwright test .claude/e2e/compiled/<flow>.spec.ts` against live server. **Compile-only (artifact + type-check green) FAILS verify.** SEC-10 C8: chip-click step missing option-select; artifact existed, browser would have asserted-failed. No flow file → degrade to `ui` AND log `[D2-candidate]` for missing coverage. |

**New API contract surface — mandatory curl smoke** (separate from spot-check sampling): every NEW `api`-type DC (router endpoint, filter contract, query schema) requires ≥1 curl probe on the live server exercising a non-trivial path (real filter operator / RBAC verb / query shape). Sampling 2-of-N can miss the new contract; per-new-surface curl cannot. Record in `### Runtime Verification → api smokes`.

| Spot-check outcome | Action |
|---|---|
| Both DCs match execute | Trust remaining DCs based on evidence; advance |
| 1 mismatch | Re-run the mismatched DC's neighbors (same type or code area); neighbor mismatch → 4.3 |
| Both mismatch | 4.3 — evidence unreliable |

### 4.3 — Fallback: full re-run

Re-run every DC procedure via 4.2 type-dispatch table. Each result: infra-fail (feedback automated) or assertion-fail (specific evidence logged).

### 4.4 — Captain-smoke pre-automation (UI-type DCs)

Automated pre-check runs BEFORE captain manual visual smoke. Captain's eyeball is final pass, not first defence.

**Primitive triage** (dispatch per DC to the narrowest that fits):

| Primitive | When | Input |
|---|---|---|
| `ship-flow:ui-verify` | Static CSS / tokens / computed-style regression — fixed selectors × expected values | `.claude/e2e/ui-verify/<slug>.yaml` |
| `e2e-pipeline:e2e-test` | Dynamic behavior / DOM assertion / navigation / step-based flow | `.claude/e2e/flows/<slug>.yaml` |
| `e2e-pipeline:e2e-walkthrough` | No declarative artifact; exploratory screenshot + optional video of affected pages | affected route list |
| `agent-browser` CLI (break-glass) | skill wrapper unavailable / mapping missing / skill invocation errors | inline JS via `eval` on live dev server |

**Runtime-mandatory cascade** (SEC-10 C8): declarative skill → agent-browser CLI → manual captain smoke. ≥1 tier MUST **execute against the live worktree dev server** (Step 4.0 green) on every UI-type DC. The cascade picks WHICH primitive — not WHETHER one runs.

**Anti-pattern**: `visual verification skipped` is only acceptable when BOTH (a) entity has zero UI-type DCs AND (b) the resolved shape artifact (`shape.md`, with legacy `spec.md` fallback alias) explicitly flags captain-smoke not required. Dev server unavailable → escalate per Step 4.0 (BLOCKER); do NOT silently skip. Compile artifact + type-check green is NOT a valid runtime substitute.

**Artifact requirement**: every pre-check produces (a) report at `.claude/e2e/reports/<slug>-<stage>-<ts>.md` OR (b) inline block in `verify.md` `### UAT → visual:`. Include ≥1 screenshot for the primary affected route. Compiled-artifact path alone is NOT a report — the report MUST cite runtime output (browser console, screenshot, playwright `--reporter=line` excerpt).

If `## Design Reference` present → compare screenshots against reference images. No reference → verify DC assertions against rendered UI.

Record verdicts under `### UAT → visual:` subsection, including which primitive ran + report path + screenshot path + per-DC pass/fail.

### Step 4.5 — Render Fidelity (T6.3, #106)

**Mandatory for all UI-type entities** (`affects_ui: true`). Cannot be skipped unless entity has zero UI-type DCs AND captain-smoke not required.

**Preflight gate** (BLOCKER if fails): Dev server MUST be live (`worktree-dev-server` check). If not live → escalate per Step 4.0. No escape.

**Process**:
1. Invoke `ship-flow:ui-verify` against live worktree dev server for each UI-type DC. Capture `getComputedStyle` results for key selectors.
2. If `## Design Output` present in entity body (design stage ran): compare rendered token values against `plugins/<app>/design/tokens.css` — must match. Flag any `D{N}|Captain decision` token that renders as hardcoded value (not CSS var reference).
3. Emit `### Render Fidelity` subsection in `verify.md` with:
   - `render_fidelity_status: pass|fail|not-applicable`
   - Per-component table: `Component | Expected token | Rendered value | Match?`
   - `## Design Output` alignment: list each D{N} decision and whether rendered output honors it
   - Screenshot path(s) for primary affected route(s)

**Failure criteria** (BLOCKING):
- Any UI-type DC rendered output does not match design token (when `## Design Output` present)
- Fake/stub interactive element (`<div onClick>` instead of `<button>`) detected in render
- Sidebar layout structural mismatch vs design spec

**Emit to entity body**: `render_fidelity_status` field feeds `### Hand-off to Review` block for cross-review audit trail.

---

## Step 5 — Auto-fix NITs inline (before verdict)

**Apply only when ALL criteria met** (never BLOCKING / WARNING):
- Severity ≤ NIT AND
- Scope ∈ {comment, docstring, header inventory} — no logic, type, behavior change AND
- Single file, ≤ 5 LOC net AND
- Mechanical (no judgment between alternatives)

For each eligible finding: Edit fix → re-run affected quality check → commit with explicit path (`git add <path> && git commit -m "fix(<component>): <summary> (verify NIT-<N>)" -- <path>`).

**Also auto-codify** knowledge captures that match inline-to-skill (captain principle: MEMORY last resort — check if lesson can be inlined into workflow first):

| Capture pattern | Action |
|---|---|
| Lesson applies to specific skill stage at specific step | Inline-edit the skill file (add gate / check). Record commit SHA in capture; downgrade `[D2-candidate]` → `[inlined]`. |
| Lesson is cross-skill / cross-project / behavioral | Leave as `[D2-candidate]` for ship-review → CLAUDE.md candidacy. |
| Entity-specific one-off | Leave as `[D1]`. |

**Anti-pattern**: do NOT auto-fix findings that touch logic, do NOT rewrite core skill procedures (only add gates / strengthen existing rules).

Record fixes in `### Verdict → auto_fixes:` with `{finding-id, commit-sha, before/after summary}`.

### Step 5.5 — Strengthen weak DCs in-place (before verdict)

When re-running a DC reveals the test mechanism has a coverage gap (tautological assertion, single-source-of-truth where multi-source would be more robust, narrow case coverage), verifier MAY extend the test in-place — preempting the finding rather than deferring as a follow-up that dies in backlog.

**Apply only when ALL criteria met**:
- Re-run shows the DC is technically passing but assertion is weak (e.g., asserts source X equals source X re-framed; or only one of N possible sources-of-truth is checked) AND
- Strengthening fits in entity's EXISTING test files (no new files / no new test infra) AND
- Strengthening is ≤30 LOC net AND
- Strengthened DC still GREEN against current implementation

For each eligible DC: Edit test → re-run → confirm GREEN under new assertion → commit with explicit path (`git add <test-path> && git commit -m "test(<entity>): strengthen DC-<N> — add <Mth> source-of-truth (verify)" -- <test-path>`).

Record in `### Verdict → strengthened_dcs:` with `{dc-id, commit-sha, before→after sources count, summary}`.

**Anti-pattern**: do NOT change WHAT the DC asserts (spec drift); do NOT add logic the implementation doesn't yet support (scope expansion). Only ADD an additional source-of-truth that confirms the same assertion via a different mechanism.

**Why distinct from Step 5 auto-fix**: auto-fix repairs an existing finding (something was wrong); strengthening preempts findings (test passes but could be more rigorous). Both apply at verify stage; both commit BEFORE PASS verdict.

**Origin**: pitch-096.5 ship-verify — DC-5 structural-parity originally asserted column count via 2 sources (header tags + CSS `gridTemplateColumns` track count). Verifier added 3rd source (row cell count) at commit `6dea77fe`; refactor that decoupled cells from header would have silently broken parity if only 2 sources agreed. **Cousin**: D1 `Bundle mid-wave fixes into wave-task commit (2026-04-21)` — same "fix at moment of discovery" principle, executer-stage equivalent.

---

## Step 6 — Write `verify.md` + cross-review gate

**Atomic write** via Layer C writer — Wave 5 primitive landed at commit `acd73545`; invoke via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=verify --entity=<id>-<slug>`. Writer handles atomic commit with explicit pathspec. No `-a`/`-A` (MEMORY #14/#25/#37).

**Section tagging (mandatory)** — every H2/H3 wrapped in paired `<!-- section:tag -->` ... `<!-- /section:tag -->`. Tag list + field semantics: `plugins/ship-flow/references/entity-body-schema.yaml → stages.verify`. Required subsections:
- `### Quality Gate` — per-surface scoping decisions + check results + pre-existing attributions
- `### Review Findings` — pre-scan + classified haiku table (file:line, severity, source, description)
- `### Knowledge Captures` — `[D1]` / `[D2-candidate]` / `[inlined]` tags
- `### Runtime Verification` — Step 4.0 preflight + per-DC runtime probes (template below). **Mandatory** if entity has any `api`/`ui`/`e2e`-type DC.
- `### UAT` — mode line + results table with `Verify` column. Per-DC entry MUST be `DC-X PASS (runtime: <command> → <result excerpt>)`; legacy `conditional (artifact-only)` / `API offline` shorthand is rejected.
- `### Verdict` — `status:` (grep gate — `passed` | `failed` | `blocked`), `stage_cost:`, `claim_records: required VERIFIED=<n> NOT VERIFIED=<n> INCONCLUSIVE=<n>; advisory VERIFIED=<n> NOT VERIFIED=<n> INCONCLUSIVE=<n>`, `auto_fixes:`, `started_at:` / `completed_at:` / `duration_minutes:`

Before emitting final status, count required and advisory claim records by verdict. Apply the claim-record dominance rules first, then existing quality/review/UAT gate rules. `status: passed` is invalid when a required claim record is missing, `NOT VERIFIED`, or unresolved `INCONCLUSIVE`.

**`### Runtime Verification` template** (capture every executed runtime command for audit + replay):

```markdown
<!-- section:runtime-verification -->
### Runtime Verification

Preflight (Step 4.0):
- dev_server: `Skill: worktree-dev-server` → frontend:<port>, api:<port> @ <ISO ts>
- api_health: `curl -sfN <api>/<liveness>` → 200, body excerpt
- ui_shell:   `curl -sfN <route> | head -100` → rendered shell match

Per-DC runtime probes:

| DC | Type | Command | Result | Verdict |
|---|---|---|---|---|
| DC-N | api/ui/e2e | `<runtime command>` | `<status / assertion / artifact path>` | PASS/FAIL |

API smokes (one per NEW api-type DC, per Step 4.2):
- `<contract surface>`: `curl …` → <status + assertion>

Preflight or probe failures: <none | bullets with cause + remediation>
<!-- /section:runtime-verification -->
```

FO greps `^status:` for the machine-readable gate. `Verdict:` line is human-facing summary.

### Cross-review gate (Principle 6 Rule C) — skipped on `--fast`

Dispatch cross-review to counterpart teammate (`planner` if `verifier` just wrote) after `verify.md` lands. Reviewer model fallback when no team: fresh **sonnet** default; upgrade to fresh **opus** when entity's `appetite: big-batch`.

7-factor rubric adapted for verify (per INVARIANTS Principle 6 Rule C #106 T1.3 + T6.4):

| Factor | Verify interpretation |
|---|---|
| **Feasibility** | gate scope correct for diff domain (source vs non-source, scoped vs full)? |
| **Executable scope** | verdict supported by evidence, not claim? |
| **Quality** | ≥1 critical assumption verified? pre-scan ran? |
| **DC adequacy** | scoped-gate spot-checks critical DCs? |
| **Canonical sync** | canonical docs consistent post-execute (architecture-impact blocks applied)? |
| **Reverse-audit previous stage** | does verify's DC results expose a gap in execute's commit coverage? Specifically: does the `### Hand-off to Verify` `dc_status` list any FAIL that execute didn't surface? Is `render_fidelity_evidence` present for UI-type entities — and if missing, flag for `render_fidelity_status: fail`? |
| **Render Fidelity + captain-ack audit trail** | (T6.4) `### Render Fidelity` present for UI entities with `render_fidelity_status: pass\|fail\|not-applicable`? Screenshot ≥1 per route? Stub-flag audit: every `## Plan Report → Stub Flags` entry has captain-ack in `### Hand-off to Review`? |

**Reverse-audit prompt template** (T3.2 — paste verbatim into reviewer dispatch):
```
Reverse-audit: Read the entity's `### Hand-off to Verify` block.
(a) List every `dc_status` entry marked FAIL or SKIP — did execute.md surface these explicitly? (BLOCKING if execute silently skipped a failing DC)
(b) For UI-type entities: is `render_fidelity_evidence` present with ≥1 browser-verified artifact? (BLOCKING if absent — per FM#4 fidelity gap prevention)
(c) Does `### Hand-off to Review` reflect the actual verify verdict honestly? (WARNING if verdict is softened relative to DC evidence)
Coaching note: silent DC failures here propagate to main as undetected regressions — enforces FM#4 (fidelity gap) and Bad-news-early motto.
```

Verdict: **PROCEED** → TaskUpdate verify=completed, FO advances. **VETO** → feedback-to-execute (max 2 rounds per stage; round 3 → PROMPT_CAPTAIN). **PROMPT_CAPTAIN** → halt, present `verify.md` + reviewer concern. Each verdict MUST include a one-sentence coaching note per INVARIANTS Rule C ABC clause.

**Circuit breaker**: if `SendMessage(planner)` is unresponsive (phantom team / timeout / fresh-Agent stall), fall back per INVARIANTS Rule A Fallback — fresh sonnet by default, fresh opus on `big-batch`. Do not block on an unresponsive reviewer.

`--fast` captain mode skips this gate; captain takes responsibility for the bypass.

### Step 6.0 — Write FO verify status receipt

When the final cross-review verdict is **PROCEED**, write the autonomous
gate receipt before any status mutation. Build the receipt only from
already-checked verify evidence; do not re-run policy checks here.

Write a temporary YAML payload whose first non-empty line is `receipt_id`, then
append it through the shared helper:

```bash
ENTITY_FOLDER="<entity-folder>"
FO_RECEIPT_FILE="$(mktemp "${TMPDIR:-/tmp}/fo-verify-receipt.XXXXXX")"
cat > "$FO_RECEIPT_FILE" <<'YAML'
receipt_id: fo-<YYYYMMDDTHHMMSSZ>-verify-proceed-auto-advance
created_at: "<ISO-8601 UTC>"
actor: "first-officer"
transition:
  from: verify
  to: verify
  trigger: verify-proceed-auto-advance
decision: self-approved
verdict: PROCEED
rule_source: plugins/ship-flow/skills/ship-verify/SKILL.md
evidence:
  verify_artifact: verify.md
  claim_records: "required VERIFIED=<n> NOT VERIFIED=0 INCONCLUSIVE=0"
  cross_review_verdict: PROCEED
preconditions:
  - name: verify.md exists and has status passed
    status: pass
  - name: required claims verified
    status: pass
  - name: cross-review verdict permits advance
    status: pass
blocker_scan:
  missing_verify_md: none
  missing_hand_off_to_review: none
  required_not_verified: none
  invalid_required_inconclusive: none
  veto: none
  prompt_captain_required: false
open_decisions: []
next_action: "record verify stage status"
YAML

bash plugins/ship-flow/lib/write-fo-receipt.sh \
  --entity-folder "$ENTITY_FOLDER" \
  --receipt-file "$FO_RECEIPT_FILE" \
  --transition-slug verify-proceed-auto-advance
```

If `plugins/ship-flow/lib/write-fo-receipt.sh` refuses the payload, stop and
prompt the captain with the helper diagnostic. Missing `verify.md`, missing
`### Hand-off to Review`, missing hand-off evidence from earlier stages,
required `NOT VERIFIED`, invalid required `INCONCLUSIVE`, `VETO`, and
`PROMPT_CAPTAIN` are captain/block routes, not self-approved receipt routes.

### Step 6.1 — Advance entity status (frontmatter wiring)

After stage artifact lands, advance sibling `index.md` frontmatter atomically:

    INDEX_MD="<entity-folder>/index.md"
    H="$(sha256sum "$INDEX_MD" | awk '{print $1}')"
    bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/advance-stage.sh" \
      --entity="$INDEX_MD" \
      --new-status=verify \
      --stage-name=verify \
      --stage-file=verify.md \
      --if-hash="$H" \
      --commit-as="verify(<id>): advance status to verify"

On exit 6 (stale hash): write `## Verify Verdict status: blocked, reason: index.md stale hash; parallel session contaminated` and return.

---

## Invariants + red flags (STOP or escalate if violated)

- **Runtime preflight (Step 4.0) MUST run before any DC re-run.** Dev server unavailable → `status: blocked`, PROMPT_CAPTAIN. NEVER advance with `conditional pass`, `API offline`, `artifact-only`, or `visual verification skipped`. Compile-only verification (artifact + type-check + unit tests) is insufficient — gate requires `e2e-pipeline:e2e-test` (or `npx playwright test …`) actually executes against live server. Every NEW api-type DC requires ≥1 curl probe against the live contract surface; sampling 2-of-N cannot substitute. (carlove SEC-10/15 Pilot Wave 1 retro, 2026-04-26.)
- Quality gate is scoped to touched surfaces (MEMORY #10); full-project noise ≠ failure.
- Per-error attribution: pattern-in-other-files does NOT excuse execute-introduced line (MEMORY #078).
- Haiku spot-check = 100% of citations, not sample (MEMORY #078 precedent).
- Default haiku pair for source-files; ZERO haiku for non-source-only diffs (Principle 3).
- UAT spot-check default; full re-run is fallback, not default.
- Auto-fix NEVER on BLOCKING/WARNING; never on logic; ≤5 LOC mechanical only.
- `verify.md` must exist with `### Verdict → status:` before exit — even on blocked pre-check.
- Pipeline invocation inherits `/ship` team; standalone may CreateTeam. Fresh-subagent only for Rule A exceptions.
- Cross-review mandatory except `--fast`; VETO feedback capped at 2 rounds per stage.
- Explicit pathspec on every commit (MEMORY #14/#25/#37). No `-a`/`-A`.
- Parallel-session diff: scope review to `files_modified` when `git log <execute_base>..HEAD --oneline | grep -v <this-slug>` non-empty.
- Feedback-to-execute capped at 2 rounds per gate (quality / review-BLOCKING / UAT); round 3 → PROMPT_CAPTAIN. Infra-fail (missing binary / server down) auto-routes; assertion-fail requires specific evidence.

<!-- section:hand-off-to-review -->
## Step 6 (Hand-off): Emit Hand-off to Review + Read Incoming Hand-off

**Read incoming**: at Step 1, read `### Hand-off to Verify` from entity body. Cross-check `dc_status` vs Verification Spec — any FAIL in execute-side DC → re-run that DC before trusting execute evidence.

**Emit** `### Hand-off to Review` after verify.md is written:
- `verify_verdict`: `passed` or `failed` (must be `passed` for review to proceed)
- `blocking_issues`: list of any BLOCKING findings from verify; must be empty for review to proceed
- `canonical_docs_touched`: confirm which canonical docs were updated in execute (INVARIANTS / README / schema); review cross-checks these
- `render_fidelity_status`: result of `### Render Fidelity` subsection — `pass`, `not-applicable`, or `fail: <reason>`
<!-- /section:hand-off-to-review -->

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml → stages.verify`.
- Per-stage writer: `plugins/ship-flow/lib/write-stage-artifact.sh --stage=verify` (landed commit `acd73545`).
- Section/map helpers: `plugins/ship-flow/lib/extract-section.sh`, `extract-map.sh`, `patch-map.sh`.
- Runtime detect: `ship-flow:ship-runtime-detect`.
- Layer A — haiku reviewers: `pr-review-toolkit:code-reviewer`, `pr-review-toolkit:silent-failure-hunter`, `trailofbits:*`, `pr-review-toolkit:{pr-test-analyzer,type-design-analyzer,comment-analyzer,code-simplifier}`.
- Layer A — agent-browser: `e2e-pipeline:e2e-test`, `e2e-pipeline:e2e-walkthrough`, `ship-flow:ui-verify`.
- Layer A — runtime preflight: project's documented dev-server boot helper (conventionally `Skill: "worktree-dev-server"` — project-level skill in adopting repos; not a ship-flow plugin skill). Required by Step 4.0.
- Layer A — inline review: `superpowers:verification-before-completion` (compatible mental model).
- Upstream: `ship-flow:ship-shape` (team spawn), `ship-flow:ship` (pipeline entry).
- Downstream: `ship-flow:ship-review` (reads `verify.md → status:`).
- Principle 6: `plugins/ship-flow/INVARIANTS.md` (Rule A continuity + Rule B 3-layer + Rule C cross-review).
- MEMORY: #5 (--next-id), #10 (scoped-gate), #14/#25/#37 (pathspec / staging), #30 (verification-dispatch), #35 (dispatch discipline, amended by Principle 6 Rule A), #078 (per-error attribution + 100% spot-check), opus-4.7-naturally-does (2026-04-23 harness diet), nextjs-16-streaming-curl-flag (turbopack `-N` requirement), **carlove-pilot-wave-1 (2026-04-26: SEC-10 #574 + SEC-15 #573 — 4 critical bugs in 4 minutes after artifact-only verify PASS; trigger for Step 4.0 + Runtime Verification subsection)**.

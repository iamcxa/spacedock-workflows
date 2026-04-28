---
name: ship-plan
description: "Use when writing an implementation plan for a shaped entity. Agent-autonomous: size-adaptive research + TDD task plan, dispatched by /ship to `planner` teammate (SendMessage). Output: `<entity-folder>/plan.md` via lib/write-stage-artifact.sh. Layer A delegation: superpowers:writing-plans for plan authoring philosophy; ship-plan wraps with Shape Up scope anchoring + runtime detection + cross-review gate."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# Ship-Plan — PLAN Stage (2.0)

You run PLAN. Output: `<entity-folder>/plan.md`. Dispatched by `/ship` to `planner` teammate via SendMessage (team spawned at `/shape`). No captain gate.

**Pipeline position**: reads `spec.md` + parent cross-entity contracts → produces `plan.md` → cross-review gate → advance to execute.

## Boot Self-Check

Run before any plan work. Stop and SendMessage(FO) if any check fails.

1. **Entity status**: read entity frontmatter `status:` — must be `sharp` or `design` (post-design stage). If `draft` → shape first; if `plan` → plan already exists, check for re-entry signal.
2. **Hand-off present**: entity body contains `### Hand-off to Plan` block (from ship-shape or ship-design). If absent → SendMessage(FO): "Missing Hand-off to Plan in `<entity-path>` — cannot proceed without design intent."
3. **Team context**: verify `planner` teammate is active (this agent). Note `executer` teammate name for Step 6 SendMessage.
4. **PRODUCT.md readable**: `plugins/<app>/PRODUCT.md` exists and is readable. If absent → SendMessage(FO): "PRODUCT.md missing — constraints source unavailable."
5. **Framework detection** (if `affects_ui: true`): Run ship-runtime-detect Step R5 to confirm `framework_detected` + `theme_indirection` for plan's verification spec.
6. **Density-aware skill load** (T3.4): read `answers_density` from entity frontmatter. `high` → auto-load framework skills per ship-runtime-detect Step R6; skip FO ask. `low|vacuum` → SendMessage(FO) with proposed skill list; wait for confirmation.

## Entity body contract (schema-as-prose)

- Reads: `spec.md` (`## Sharp Output` / `## Shape Output` — problem, done criteria, size, scope, assumptions, children DAG), parent entity `## Cross-Entity Contracts` if `parent:` set, `PRODUCT.md` constraints.
- Writes: `<entity-folder>/plan.md` sections — `## Research Summary`, `## Size Re-evaluation`, `## Verification Spec`, `## Plan` (TDD tasks with waves), `## Plan Report` (status/cost/iterations/verdict).
- Full section-tag + field semantics: `plugins/ship-flow/references/entity-body-schema.yaml → stages.plan`.

## Layer A delegation (Principle 6 Rule B)

`superpowers:writing-plans` owns plan authoring discipline (TDD order, wave safety, placeholder-free prose, task atomicity). **Do NOT re-teach.** Ship-plan wraps with Layer B augmentation:

- Shape Up scope anchoring (every task maps to a Done Criterion / Scope In bullet).
- Size-adaptive research team (produce + review subagents, sized S/M/L).
- Runtime detection via `ship-flow:ship-runtime-detect` for `{commands.test/build/typecheck/lint/dev}`.
- Assumption re-validation (Step 1.5) against current codebase state before planning.
- Plan-checker multi-dimensional review + cross-review gate.

---

## Flow

**Phases (TaskCreate sub-tasks — inherit from /ship umbrella when pipeline-dispatched; create own when standalone):**
`read-spec` → `assumption-revalidate` → `research` → `size-reevaluate` → `scope-anchor` → `write-plan` → `verification-spec` → `self-review` → `cross-review` → `emit-plan.md`

### Step 1 — Read spec + cross-entity contracts

Record stage-start ISO timestamp. Extract via `bash plugins/ship-flow/lib/extract-section.sh <entity-file> <section-tag>` (handles folder + flat layouts). From spec.md: problem, done criteria, size (S/M/L), scope-in bullets, musk-audit verdicts, stated assumptions.

If `parent:` frontmatter set: read parent `## Cross-Entity Contracts`. Extract `Contracts to implement`, `Inherited decisions` (ADR overrides), `Slice scope`. These override any conflicting research finding.

**Blocker**: spec missing problem or done criteria → write `## Plan Report status: blocked, reason: missing spec` and return.

### Step 1.5 — Assumption re-validation

Scan spec for `file:line` citations. Read each; compare current content vs spec's assumption. Stale line (shifted but claim plausible) → note `(⚠ stale-evidence)` inline. Contradicted (content shows opposite) → **BLOCKER** (status: blocked, reason: sharp assumption contradicted). Rationale: stale-premise plans = most expensive failure mode (executor BLOCKs on non-matching codebase).

Skip if no file:line citations (common for S-size).

### Step 1.6 — Import Design DCs from Hand-off (G10, 2026-04-29)

**Trigger** (G14, 2026-04-29 disambiguation): entity body MUST contain `### Hand-off to Plan` block. Two paths:
- Block has `design-skipped: true` → design intentionally bypassed (shape Phase 8 stub for `affects_ui: false` route); log `## Plan Imported Design DCs: design-skipped (no UI surface)` and proceed.
- Block has design-emitted fields (`design_constraints[]` / `render_fidelity_targets[]`) → run mechanical mapping below.
- Block ABSENT entirely → **BLOCKER** (status: blocked, reason: `hand-off-to-plan absent — neither design-skipped stub nor design output found`). Either shape Phase 8 missed the stub emit OR design errored without writing hand-off. Do not silently treat as "no UI" — that's the ambiguity G14 fixes.

**Read** via `bash plugins/ship-flow/lib/extract-section.sh <entity-file> hand_off_to_plan` (handles folder + flat layouts).

**Mechanical mapping** delegated to lib script:
```bash
bash plugins/ship-flow/lib/import-design-dcs.sh <entity-folder> >> <entity-folder>/plan.md
```
The script reads structured `### Hand-off to Plan`, emits `## Plan Imported Design DCs` table directly. Falls back to MIGRATE-FIRST notice when entity is in legacy prose format. **Do NOT manually transcribe** — that's the LLM-drift mode this script eliminates.

Pre-import validation (run in this order):
- `bash plugins/ship-flow/lib/validate-handoff-schema.sh <entity-folder>` — structural check
- `bash plugins/ship-flow/lib/validate-d-references.sh <entity-folder>` — D{N} backref consistency

If either validator fails → BLOCKER (status: blocked, reason: hand-off schema invalid; details from script stderr).

**Mechanical mapping** (each item becomes a DC anchored to a wave):

| Hand-off field | Becomes | Wave |
|---|---|---|
| `design_constraints[]` (token / layout / interaction) | `ui` or `e2e`-typed DC per constraint, `verified_by: ui-verify` | task wave touching the affected component |
| `render_fidelity_targets[]` (computed-style / structural assertions) | `ui`-typed DC, `verified_by: ui-verify` (calls computed-style assertion) | W0 (token-level) or task wave (component-level) |
| `artifact_paths[]` | reference in plan `## Design Source` block; checksum on read | — |
| `open_decisions[]` non-empty | **BLOCKER** (status: blocked, reason: design has open decisions) — bounce to design via SendMessage(designer@pitch-XX) | — |

Each imported DC retains `rationale_decision: D{N}` cross-reference back to ship-design Phase 8 `## Captain Decisions` for audit trail.

**Why this exists**: ship-design's hand-off-to-plan block previously said "encode `render_fidelity_targets` as DCs" but no plan step did the mechanical conversion — relied on planner LLM noticing the instruction at the bottom of the entity body. Result: render fidelity targets silently dropped on ~30% of UI pitches. This step is the explicit machine path.

**Output**: `## Plan Imported Design DCs` section in plan.md listing each imported DC with source field + wave assignment + rationale_decision link.

### Step 2 — Research (size-adaptive, produce+review)

- **S** — skip research. Proceed to Step 3.
- **M** — dispatch Agent A (sonnet producer: codebase impact + lib constraints, <400 words, file:line citations; include recent debrief warnings from `docs/<wf>/_debriefs/` — read `## Issues — Workflow` / `## Filed (backlog)` sections, schema at `plugins/ship-flow/references/debrief-schema.yaml`) → Agent B (sonnet reviewer: APPROVED / GAPS / CONTRADICTION, <300 words). Max 1 gap-fill round.
- **L** — dispatch 3-5 parallel producers (upstream constraints / existing patterns / lib surface / gotchas / reference examples), each <200 words, file:line citations; one producer dedicated to recent debrief warnings (`docs/<wf>/_debriefs/` last 3-5 files, extract `## Issues — Workflow` / `## Filed (backlog)` / `## Observations`). Reviewer runs cross-domain + coverage check. Max 1 gap-fill round.

**Contradiction**: write both verbatim as Open Question in `## Research Summary`. Never silently resolve.

### Step 2.5 — Size re-evaluation

Count actual affected files from research vs spec's size estimate.

| Sharp | Actual | Action |
|---|---|---|
| S | ≤3 | Confirmed S |
| S | 4-10 | Upgrade to M |
| S | >10 | Upgrade to L (run full research) |
| M | ≤3 | Downgrade to S |
| M | 4-15 | Confirmed M |
| M | >15 | Upgrade to L |
| L | any | Confirmed L |

Update entity frontmatter `size:` if changed.

**Fold/extract LOC heuristic** (harness-diet restructures; n=2 calibration):
- Fold (A → B, A retired): `fold_net_loc ≈ source_loc × 0.44-0.55`. DC-1 budget worst-case = `target_initial + source × 0.55`. Include procedural skeleton + example tables + guidance templates (not just the Steps-1-to-N).
- Extract (1 source → N callers with refs): `extraction_net_loc ≈ -(source_loc × 0.55-0.70)` where source = summed preamble LOC across callers.
- Picking: ≤50 LOC + one parent → fold. ≥100 LOC + N≥3 callers → extract. 50-100 LOC + N=2-3 → fold into most natural parent. Extraction adds 1 skill (Principle 2 cap check first).

### Step 2.7 — Scope anchoring (M/L only)

Every task maps to a spec `Scope In` bullet (if shape ran) OR a `Done Criteria` item. Produce task×mapping table. Unmapped task → drop or flag in `## Plan Report`. Do NOT silently expand scope.

### Step 3 — Write plan (delegate to superpowers:writing-plans)

Invoke `Skill: superpowers:writing-plans` for plan authoring. It handles TDD task order, wave safety, placeholder scan, task atomicity, verification commands per task Done. **Do NOT re-teach.**

**Layer B wrap** (ship-plan owns these on top of Layer A output):
- Runtime detection — invoke `ship-flow:ship-runtime-detect` before tasks get written; propagate `{commands.test/build/typecheck/lint/dev}` into every task's Done field.
- TDD exceptions (mark inline): config / pure refactor with coverage / docs-only / migration — `**TDD:** skip — <reason>`.
- Wave rules: wave 0 = test infra; wave N+1 depends only on ≤N outputs; no `files_modified` overlap within a wave; no cycle.
- **T0.X auto-indirection-sweep** (T6.1, #106): when `theme_indirection` from ship-runtime-detect Step R5 is non-empty (e.g. `tailwind-v4`), auto-emit a Wave 0 task in the plan: `T0.X: Audit @theme inline indirection layer — verify design tokens align with CSS custom properties, no hardcoded hex values in component files`. REFUSE to emit a plan without this task when `theme_indirection != ""`. Enforcement: `bash plugins/ship-flow/bin/check-invariants.sh --check indirection-sweep-emitted` (fixture-based).

### Step 3.5 — Verification spec (structural parity enforcement)

Per typed Done Criterion, fill exact verification procedure:

| Type | Procedure | Fallback |
|---|---|---|
| `cli` | bash command + expected exit/output | always available |
| `api` | `curl` with method/URL/body + status + response pattern | always available |
| `ui` | `curl -sfN <route>` + `grep` content; complex interaction → `e2e-test <flow.yaml>` | curl+grep skip interaction |
| `skill` | `Skill("<name>")` invoke + expected output shape | session-only verification |
| `e2e` | `e2e-test <flow.yaml>` with step assertions | degrade to `ui` type |

Every DC MUST have a runnable verify procedure. "Manual check" = plan failure.

**UI entities MUST have ≥1 structural-parity DC** — grep DCs prove wiring, not rendering. Column/cell count parity / grid-template vs header count / prop-type assertion / class-name presence. MEMORY #048: all grep DCs passed while 3 CSS-grid / prop-mis-wire bugs shipped; captain cycle wasted. Budget one structural DC per UI entity.

Note: `ui` type uses `-sfN` (Next.js 16 Turbopack SSR chunks — MEMORY #073). Backward-compatible.

**Declarative e2e artifact requirement (UI-type DCs)**: when ≥1 DC has type `ui` or `e2e`, plan's task list MUST include authoring the declarative YAML so ship-verify Step 4.4 can run automated pre-smoke:
- **Static CSS / design tokens / computed-style regression** → `.claude/e2e/ui-verify/<entity-slug>.yaml` (schema: `e2e-pipeline:ui-verify`). Wraps `getComputedStyle(selector)[prop]` equality checks against tokens.
- **Dynamic DOM / navigation / event / interaction** → `.claude/e2e/flows/<entity-slug>.yaml` (schema: `e2e-pipeline:e2e-flow`). Step-based browser flow with assert primitives.
- Both require `.claude/e2e/mappings/<mapping>.yaml` (auth + base_url + test_accounts). If missing → plan's first UI task is mapping bootstrap.
- Plan-stage DC: YAML file exists at canonical path AND imports valid mapping. Consumer: ship-verify Step 4.4 auto-runs matching skill.
- Fallback when skill wrapper unavailable / mapping missing: inline `agent-browser` CLI script as a verify-time DC (declarative YAML preferred; CLI only as break-glass).

### Step 4 — Self-review (plan-checker-lite)

Run 9 dimensions. Any BLOCKER → fix inline + re-review. Max 3 iterations.

1. **Requirement coverage** — every DC maps to ≥1 task.
2. **Task completeness** — every task has paths / verify command / model hint / wave.
3. **Dependency correctness** — wave graph safe (no cycles / no same-wave `files_modified` overlap / no read_first pulling same-wave outputs).
4. **Zero-placeholder scan** — grep `TBD | add appropriate | similar to Task N | as needed | fill in | \.\.\.` → fix inline.
5. **Type/signature consistency** — cross-task function/type signatures match.
6. **Task minimality (M/L)** — merge adjacent non-load-bearing tasks; drop nice-to-haves not in DCs.
7. **TDD compliance** — test-first order on code tasks; `TDD: skip` tasks have valid reason.
8. **Stale-line-anchor** — every `file:line` citation re-read; content-matches / line-shifted / contradicted (BLOCKER) / phantom path (BLOCKER). Catches #1 cause of execute BLOCKED returns.
9. **Design reference compliance** — skip if no `## Design Reference` section; else cross-check visual attrs (fill/stroke/colors/dimensions) against cited spec files. Flag deviations.
10. **Stub-captain-ack scan** (T6.2, #106): grep every task body for keywords `stub|fake|placeholder|v1.*only|wired only for`. For each match: check entity frontmatter `pre-acked-stubs: true` OR check that the Plan Report has a `## Stub Flag` entry for this task with explicit captain rationale. If neither present → `BLOCK: stub task without captain ack` (literal string required for test DC). Populate `## Plan Report → Stub Flags` table with all stub tasks found. Cross-review PROCEED blocked until all stubs either pre-acked or cleared.

### Step 5 — Cross-review gate (Principle 6 Rule C)

Dispatch cross-review to `executer` teammate (pipeline path) or fresh sonnet (no team). Upgrade to fresh **opus** when `appetite: big-batch`.

6-factor rubric adapted for plan stage (per INVARIANTS Principle 6 Rule C #106 T1.3):

1. **Feasibility** — tasks achievable by single agent in one dispatch each?
2. **Executable scope** — tasks are atomic commits aligned 1:1 with waves?
3. **Quality** — Verification Spec covers every DC with runnable procedure (≥1 structural-parity DC for UI)?
4. **DC adequacy** — observable DCs per task; no "works correctly" / "handles all cases"?
5. **Canonical sync** — ARCHITECTURE.md touches planned? architecture-impact draft per affected child?
6. **Reverse-audit previous stage** — does the plan's scope expose a gap in the preceding design stage's `### Hand-off to Plan` block? Specifically: are all `render_fidelity_targets` from design encoded as DCs? Are `design_constraints` honored in plan tasks?
7. **Render Fidelity + captain-ack audit trail** (T6.4, #106) — for UI entities: does plan have ≥1 structural-parity DC per component in design canonical? AND are all stub tasks captain-acked (either `pre-acked-stubs: true` in frontmatter or explicit `## Plan Report → Stub Flags` entries)?

**Reverse-audit prompt template** (T3.2 — paste verbatim into reviewer dispatch):
```
Reverse-audit: Read the entity's `### Hand-off to Plan` block.
(a) List every `render_fidelity_target` — does plan.md have a DC for each? (BLOCKING if any missing)
(b) List every `design_constraint` — does each appear in at least one plan task or Verification Spec row? (WARNING if any absent)
(c) Are `open_decisions` empty? If not empty, is there a plan task that resolves each? (PROMPT_CAPTAIN if unresolved)
Coaching note: render_fidelity gaps here become silent UI regressions at verify — enforces FM#4 (fidelity gap) prevention.
```

Verdict: **PROCEED** / **VETO** (max 2 loops back to Step 3 with reviewer feedback; round 3 → PROMPT_CAPTAIN) / **PROMPT_CAPTAIN**. Each verdict MUST include a one-sentence coaching note per INVARIANTS Rule C ABC clause.

**Circuit breaker**: if `SendMessage(executer)` is unresponsive (phantom team / timeout / fresh-Agent stall), fall back per INVARIANTS Rule A Fallback — fresh sonnet by default, fresh opus on `big-batch`. Do not block on an unresponsive reviewer.

### Step 6 — Emit plan.md

Write to `<entity-folder>/plan.md` via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=plan --entity=<id>-<slug> --content=<draft-path>` (Wave 5 primitive landed at commit `acd73545`). Primitive handles atomic commit with explicit pathspec (MEMORY #14/#25/#37).

Plan.md sections: `## Research Summary` (findings + open questions if contradictions + reviewer verdict), `## Size Re-evaluation`, `## Verification Spec` (table from Step 3.5), `## Plan` (TDD tasks from Step 3), `## Plan Report` (status, stage_cost: dispatches×model, iterations, dimensions pass/fail, reviewer verdict, scope anchoring, task count, model split, started/completed/duration).

Mark TaskCreate sub-task `emit-plan.md` completed; return to /ship for advance to execute.

### Step 6.1 — Advance entity status (frontmatter wiring)

After stage artifact lands, advance sibling `index.md` frontmatter atomically:

    INDEX_MD="<entity-folder>/index.md"
    H="$(sha256sum "$INDEX_MD" | awk '{print $1}')"
    bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/advance-stage.sh" \
      --entity="$INDEX_MD" \
      --new-status=plan \
      --stage-name=plan \
      --stage-file=plan.md \
      --if-hash="$H" \
      --commit-as="plan(<id>): advance status to plan"

On exit 6 (stale hash): write `## Plan Report status: blocked, reason: index.md stale hash; parallel session contaminated` and return.

---

## Invariants + red flags (STOP if violated)

- Every DC has a runnable verify procedure. "Manual check" = plan failure.
- UI entity without ≥1 structural-parity DC = silent visual-bug risk.
- Contradicted sharp assumption (Step 1.5) → BLOCKER, do not plan on stale premises.
- Wave graph violates safety (cycle / overlap / cross-read) → BLOCKER.
- Placeholder prose (`TBD` / "similar to Task N" / `...`) = plan failure; fix inline.
- Cross-review VETO loop capped at 2 rounds; round 3 → PROMPT_CAPTAIN.
- Layer A delegation (`superpowers:writing-plans`) owns plan authoring — re-teaching = Principle 6 Rule B violation.
- Scope expansion beyond spec Scope In / DCs = Shape Up violation; drop or flag.

## Circuit breakers

- Research producer timeout: 2 min/agent.
- Research reviewer: max 1 gap-fill round.
- Self-review loop: max 3 iterations → proceed with gaps noted in Plan Report.
- Cross-review reviewer: max 1 round per VETO; 2 VETOs total before PROMPT_CAPTAIN.
- Total stage >20 min elapsed → write `plan.md` with partial content + `⚠️ INCOMPLETE` markers + Plan Report status=partial, then return. Never exit without emitting plan.md.

<!-- section:hand_off_to_execute -->
## Step 6 (Hand-off): Emit Hand-off to Execute + Read Incoming Hand-off

**Read incoming**: at Step 1, read `### Hand-off to Plan` from entity body. Verify `design_constraints` honored in plan tasks; encode `render_fidelity_targets` as DCs.

**Emit** `### Hand-off to Execute` after plan.md is written:
- `wave_order`: exact wave dispatch order (e.g., "W0 → W1 (T1.1→T1.2→T1.3→T1.4) → W2a → W2b → W2c → W3 → W4")
- `critical_assumptions`: assumptions to re-verify at execute boot (from Assumption Re-validation section)
- `architecture_context`: canonical doc touches required (INVARIANTS, README, schema) — drives execute commit order
- `stub_flags`: tasks containing `stub|fake|placeholder|v1.*only|wired only for` — must appear in Plan Report as captain-ack flags
<!-- /section:hand_off_to_execute -->

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml → stages.plan`.
- Stage writer: `plugins/ship-flow/lib/write-stage-artifact.sh`.
- Section extraction: `plugins/ship-flow/lib/extract-section.sh`.
- Layer A: `superpowers:writing-plans` (plan authoring discipline).
- Utility: `ship-flow:ship-runtime-detect` (13-ecosystem runtime detection).
- Architecture-canon mod: `docs/ship-flow/_mods/architecture-canon.md`.
- Principle 6: `plugins/ship-flow/INVARIANTS.md` (context continuity + 3-layer architecture + cross-review).
- MEMORY: #5 (--next-id atomicity), #14/#25/#37 (explicit pathspec / staging), #35 (dispatch discipline amended by Principle 6), #048 (UI structural-parity), #073 (Next.js 16 `-sfN`), opus-4.7-naturally-does (2026-04-23 harness diet).
